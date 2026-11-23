import Dispatch
import Foundation
import Synchronization
import ThreadAffinityExecutor

public final class JSVirtualMachine<E: JSEngineRuntimeDriver>: Sendable {
  package let driverRuntimeHandle: E.RuntimeHandle
  private let owner: VMThread.Owner
  /// Retained so registry cleanup jobs can be scheduled without retaining the
  /// VM itself; the `Owner` is what stops the thread.
  private let thread: VMThread
  public let unownedExecutor: UnownedSerialExecutor

  public convenience init() {
    self.init(thread: VMThread())
  }

  /// Engine access only on the VM thread (design §0.2.3). The runtime is
  /// created there too, so no engine call of this library ever runs on
  /// whichever thread happens to construct a VM or a context.
  private init(thread: VMThread) {
    let factory: any EngineLifecycle = EngineFactory<E>()
    let runtime = thread.runAndWait {
      factory.makeRuntime()
    }
    self.driverRuntimeHandle = runtime as! E.RuntimeHandle
    self.unownedExecutor = thread.unownedExecutor
    self.owner = thread.owner
    self.thread = thread
  }

  /// The engine context for a new `JSContext` on this VM, created on the VM
  /// thread: creating a context mutates the shared runtime, which that
  /// thread may be using for the VM's other contexts.
  func makeContextHandle() -> E.ContextHandle? {
    let factory: any EngineLifecycle = EngineFactory<E>()
    let runtime: any Sendable = driverRuntimeHandle
    let context = thread.runAndWait {
      factory.makeContext(in: runtime)
    }
    return context as? E.ContextHandle
  }

  /// Scheduling handle for persistent-binding settlement (design §2.4
  /// option b). Cleanup closures run on the same serial OS thread as actor
  /// jobs, so payload settlement never escapes the VM thread.
  package var persistentCleanupScheduler: any JSPersistentCleanupScheduler {
    thread
  }

  /// The VM's dedicated thread, for work that must not touch the engine
  /// from any other thread (thread-safe context-data storage swaps).
  var vmThread: VMThread {
    thread
  }

  deinit {
    // An engine call, so it belongs on the VM thread (design §0.2.3). Every
    // context retained the VM, so by now they are all gone and the thread is
    // idle; the release completes before `Owner` stops the thread.
    let runtimeHandle = driverRuntimeHandle
    thread.runAndWait {
      _ = runtimeHandle.releaseReference()
    }
  }
}

extension JSVirtualMachine: Equatable where E.RuntimeHandle: Equatable {
  public static func == (lhs: JSVirtualMachine<E>, rhs: JSVirtualMachine<E>) -> Bool {
    lhs.driverRuntimeHandle == rhs.driverRuntimeHandle
  }
}

extension JSVirtualMachine: Hashable where E.RuntimeHandle: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(driverRuntimeHandle)
  }
}

/// The VM's dedicated thread: `ThreadAffinityExecutor`'s
/// `DedicatedThreadExecutor` plus the VM-thread entry points built on it.
///
/// Actor jobs and VM-thread closures share the executor's one FIFO: a task
/// created with the executor as preference is enqueued on it directly
/// (SE-0417: "Tasks created this way are immediately enqueued on given
/// executor"), so registry settlement and storage-box swaps keep their
/// position relative to actor jobs, and all engine access stays on one OS
/// thread (design §0.2.3).
final class VMThread: JSPersistentCleanupScheduler {
  let executor: DedicatedThreadExecutor

  /// The executor's `init` throws only when the lifecycle's `initialize`
  /// does, and the default lifecycle never does.
  init() {
    guard let executor = try? DedicatedThreadExecutor() else {
      preconditionFailure("JSVirtualMachine could not create its dedicated thread")
    }
    self.executor = executor
  }

  /// The handle actors bind to.
  var unownedExecutor: UnownedSerialExecutor {
    executor.asUnownedSerialExecutor()
  }

  /// Whether the caller is the VM thread — `ThreadBoundExecutor`'s isolation
  /// check, which is thread identity.
  func isIsolatingCurrentContext() -> Bool {
    executor.isIsolatingCurrentContext() == true
  }

  /// Enqueue a closure on the VM thread. The body is synchronous, so none of
  /// the documented ways a task leaves its preferred executor (resumption
  /// after a suspension point) can apply. After `shutdown` was requested the
  /// job is dropped: every binding was settled inline by `close()` before
  /// shutdown, so dropping cannot leak a binding (design §2.4). What a
  /// dropped job can still cost is the release of a self-owning input that
  /// outlived its VM — a leak, where running it would touch a freed runtime.
  func scheduleOnVMThread(_ body: @escaping @Sendable () -> Void) {
    // Detached, so the task inherits nothing from the caller — in particular
    // not the isolation of a foreign actor the caller may be running on.
    Task.detached(executorPreference: executor) {
      body()
    }
  }

  func schedulePersistentCleanup(_ body: @escaping @Sendable () -> Void) {
    scheduleOnVMThread(body)
  }

  /// Run `body` on the VM thread: inline when the caller already is that
  /// thread, otherwise posted — the call returns before the body runs.
  func perform(_ body: @escaping @Sendable () -> Void) {
    if isIsolatingCurrentContext() {
      body()
    } else {
      scheduleOnVMThread(body)
    }
  }

  /// Run `body` on the VM thread and return its result: inline when the
  /// caller already is that thread, otherwise posted and waited for.
  ///
  /// For the engine calls that must be complete when a synchronous
  /// constructor or destructor returns — context and runtime creation,
  /// runtime teardown. The VM thread never waits on its callers, so the wait
  /// cannot deadlock; the one thing an embedding must not do is block the
  /// engine on a thread that is itself waiting here.
  @available(*, noasync)
  func runAndWait<R: Sendable>(_ body: @escaping @Sendable () -> R) -> R {
    if isIsolatingCurrentContext() {
      return body()
    }
    let result = Mutex<R?>(nil)
    let done = DispatchSemaphore(value: 0)
    Task.detached(executorPreference: executor) {
      result.withLock { $0 = body() }
      done.signal()
    }
    done.wait()
    return result.withLock { $0! }
  }

  /// Stop the VM thread once nothing can submit further work: the VM is
  /// being destroyed, so every context — and every job it could enqueue —
  /// is gone. Queued work drains first.
  func shutdown() {
    if executor.threadID == ThreadID.current {
      // The last reference to a VM can be released on its own thread: a
      // context's isolated deinit ends there and drops the VM it retained.
      // `shutdown()` must not be called from the bound thread, so hand it to
      // a global-queue thread; nobody is left to join.
      DispatchQueue.global().async {
        self.executor.shutdown()
      }
    } else {
      executor.shutdown()
    }
  }

  /// Shutdown token held by the VM. The scheduler handed to registries and
  /// the tasks in flight retain the `VMThread`; only the `Owner` stops it.
  struct Owner: ~Copyable {
    let thread: VMThread
    deinit {
      thread.shutdown()
    }
  }

  var owner: Owner {
    Owner(thread: self)
  }
}

/// The engine's lifecycle statics behind a `Sendable` existential, so they
/// can be posted to the VM thread by a closure that captures a value instead
/// of `E.Type` (same shape as the registry's pump target). Results are erased
/// and cast back outside the posted closure.
private protocol EngineLifecycle: Sendable {
  func makeRuntime() -> any Sendable
  func makeContext(in runtime: any Sendable) -> (any Sendable)?
}

private struct EngineFactory<E: JSEngineRuntimeDriver>: EngineLifecycle {
  func makeRuntime() -> any Sendable {
    E.makeRuntimeHandle()
  }

  func makeContext(in runtime: any Sendable) -> (any Sendable)? {
    E.makeBorrowedContextHandleFromRuntime(in: runtime as! E.RuntimeHandle)
  }
}
