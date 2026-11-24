import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// The QuickJS virtual machine: one runtime plus the dedicated VM thread every
/// context of this VM runs on.
///
/// Engine access only happens on that thread (design §0.2.3): the runtime is
/// created there, every context handle is created there, and the runtime is
/// released there in the same order as before — `JS_FreeRuntime`, then the
/// class/record registries, then the runtime identity entry.
/// `nonisolated ==`/`hash` use the runtime handle.
public final class QJSVirtualMachine: SwiftJavaScript.JSVirtualMachine,
  @unchecked Sendable
{
  public typealias Context = QJSContext
  public typealias ContextHandle = QJSContextHandle
  public typealias RuntimeHandle = QJSRuntimeHandle

  public let driverRuntimeHandle: QJSRuntimeHandle
  public let unownedExecutor: UnownedSerialExecutor

  private let owner: VMThread.Owner
  /// Retained so registry cleanup jobs can be scheduled without retaining the
  /// VM itself; the `Owner` is what stops the thread.
  private let thread: VMThread

  public convenience init() {
    self.init(thread: VMThread())
  }

  private init(thread: VMThread) {
    let runtime = thread.runAndWait {
      QJSEngine.makeRuntimeHandle()
    }
    self.driverRuntimeHandle = runtime
    self.unownedExecutor = thread.unownedExecutor
    self.owner = thread.owner
    self.thread = thread
  }

  /// The engine context for a new `QJSContext`, created on the VM thread:
  /// creating a context mutates the shared runtime, which that thread may be
  /// using for the VM's other contexts.
  public func makeContextHandle() -> QJSContextHandle? {
    let runtimeHandle = driverRuntimeHandle
    return thread.runAndWait {
      QJSEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
    }
  }

  /// Run QuickJS's garbage collector. Engine work, so the caller is expected
  /// to be on the VM thread (a context callback or the actor's isolation).
  public func gc() {
    JS_RunGC(driverRuntimeHandle.ref)
  }

  /// Scheduling handle for persistent-binding settlement (design §2.4
  /// option b). Cleanup closures run on the same serial OS thread as actor
  /// jobs, so payload settlement never escapes the VM thread.
  package var persistentCleanupScheduler: any JSPersistentCleanupScheduler {
    thread
  }

  /// The VM's dedicated thread, for work that must not touch the engine from
  /// any other thread (thread-safe context-data storage swaps).
  package var vmThread: VMThread {
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

  public static func == (lhs: QJSVirtualMachine, rhs: QJSVirtualMachine) -> Bool {
    lhs.driverRuntimeHandle == rhs.driverRuntimeHandle
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(driverRuntimeHandle)
  }
}
