import Dispatch
import JavaScriptCore
import SwiftJavaScript
import Synchronization
import ThreadAffinityExecutor

/// The JavaScriptCore virtual machine: one context group plus the executor
/// every context of this VM runs on.
///
/// Engine state is created during `init`, on the VM's executor, and released
/// by `isolated deinit` on that same executor. `init` blocks until the context
/// group exists; `init() async` waits for it without blocking. A caller that
/// already is on the executor runs the initialization inline.
/// `nonisolated ==`/`hash` use object identity.
public actor JSCVirtualMachine: SwiftJavaScript.JSVirtualMachine {
  public typealias Context = JSCContext

  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// The executor every context of this VM runs on. Package-internal so a
  /// context's initializer can hop onto it.
  package nonisolated let executor: any SerialExecutor

  /// The dedicated thread this VM created; nil when the executor is
  /// caller-supplied, whose lifetime belongs to the embedder.
  private let ownedExecutor: DedicatedThreadExecutor?

  /// The context group's bit pattern, created during init (0 until then).
  private nonisolated let runtimeBits = Mutex<UInt>(0)

  @available(*, noasync)
  public init() {
    let executor = DedicatedThreadExecutor()
    self.executor = executor
    self.ownedExecutor = executor
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    openRuntimeSynchronously()
  }

  public init(_ mode: JSInitMode) async {
    let executor = DedicatedThreadExecutor()
    self.executor = executor
    self.ownedExecutor = executor
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    await openRuntime()
  }

  /// Run every context of this VM on a caller-supplied serial executor.
  ///
  /// JavaScriptCore locks its context group internally, so the VM only needs
  /// engine access serialized, not pinned to a particular OS thread: any
  /// serial executor is safe. The executor is borrowed — this VM neither
  /// stops it nor waits for it.
  @available(*, noasync)
  public init(executor: any SerialExecutor) {
    self.executor = executor
    self.ownedExecutor = nil
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    openRuntimeSynchronously()
  }

  public init(executor: any SerialExecutor, _ mode: JSInitMode) async {
    self.executor = executor
    self.ownedExecutor = nil
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    await openRuntime()
  }

  /// Whether the caller is isolated with respect to this VM's executor.
  ///
  /// Executors that cannot answer (no thread identity) are treated as foreign:
  /// the initializer then posts the engine work instead of running it inline.
  package nonisolated func isOnVMExecutor() -> Bool {
    // Thread-affine executors answer through the package's thread-identity
    // extension on every supported platform.
    if let affinity = executor as? any ThreadAffinityExecutor {
      return affinity.isIsolatingCurrentContext() == true
    }
    if #available(macOS 26.0, *) {
      return executor.isIsolatingCurrentContext() == true
    }
    return false
  }

  /// Create the context group if it does not exist yet. Engine work: the
  /// caller runs on the VM executor — inline when `isOnVMExecutor()`, or
  /// through `JSExecutorHop` otherwise.
  private nonisolated func makeRuntimeOnExecutor() {
    runtimeBits.withLock { bits in
      guard bits == 0 else { return }
      bits = UInt(bitPattern: JSCEngine.makeRuntime())
    }
  }

  private nonisolated func runtimeHandleOnExecutor() -> JSContextGroupRef {
    makeRuntimeOnExecutor()
    return JSContextGroupRef(bitPattern: runtimeBits.withLock { $0 })!
  }

  /// The engine context for a new `JSCContext`, created on the VM executor.
  /// Returns the raw bits: the handle crosses isolation, and `UInt` is the
  /// Sendable form of an engine reference. Creating a context mutates the
  /// shared runtime.
  package nonisolated func makeContextHandleOnExecutor() -> UInt? {
    guard
      let contextRef = JSCEngine.makeBorrowedContextHandleFromRuntime(
        in: runtimeHandleOnExecutor()
      )
    else {
      return nil
    }
    return UInt(bitPattern: contextRef)
  }

  /// Isolated form for callers that come through the actor (tests).
  package func makeContextHandle() -> UInt? {
    makeContextHandleOnExecutor()
  }

  /// Ensure the group exists: inline when already isolated on the executor,
  /// otherwise enqueue on the executor and block the caller until the engine
  /// work completed.
  ///
  /// The task-executor path enqueues immediately (SE-0417) and needs no
  /// cooperative-pool thread; only a plain serial executor falls back to the
  /// hop task, which is why callers on the concurrency runtime should prefer
  /// the non-blocking initializer.
  private nonisolated func openRuntimeSynchronously() {
    if isOnVMExecutor() {
      makeRuntimeOnExecutor()
      return
    }
    let done = DispatchSemaphore(value: 0)
    if let taskExecutor = executor as? any TaskExecutor {
      scheduleOnTaskExecutor(taskExecutor) { [self] in
        makeRuntimeOnExecutor()
        done.signal()
      }
    } else {
      let hop = JSExecutorHop(executor: executor)
      Task { [self] in
        await hop.run {
          makeRuntimeOnExecutor()
        }
        done.signal()
      }
    }
    done.wait()
  }

  /// Async form: the same hop, awaited instead of blocked.
  private nonisolated func openRuntime() async {
    if isOnVMExecutor() {
      makeRuntimeOnExecutor()
      return
    }
    if let taskExecutor = executor as? any TaskExecutor {
      await runOnTaskExecutor(taskExecutor) { [self] in
        makeRuntimeOnExecutor()
      }
      return
    }
    let hop = JSExecutorHop(executor: executor)
    await hop.run { [self] in
      makeRuntimeOnExecutor()
    }
  }

  /// Isolated deinit (SE-0371): runs on the VM executor, after every context
  /// released its own reference, so the runtime release needs no bridge.
  isolated deinit {
    let bits = runtimeBits.withLock { $0 }
    if let runtime = JSContextGroupRef(bitPattern: bits) {
      JSCEngine.releaseRuntime(runtime)
    }
    if let ownedExecutor {
      // The last reference can drop on the VM thread itself: a context's
      // isolated deinit ends there and drops the VM it retained. Nobody is
      // left to join that thread, so hand the shutdown to a global-queue
      // thread; elsewhere stop it here, draining queued work first.
      if ownedExecutor.threadID == ThreadID.current {
        DispatchQueue.global().async {
          ownedExecutor.shutdown()
        }
      } else {
        ownedExecutor.shutdown()
      }
    }
  }

  public nonisolated static func == (lhs: JSCVirtualMachine, rhs: JSCVirtualMachine) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
