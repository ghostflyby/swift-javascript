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
/// created there, every context is created there, and the runtime is released
/// there in the same order as before — `JS_FreeRuntime`, then the class record
/// cache. `nonisolated ==`/`hash` use the runtime reference.
public final class QJSVirtualMachine: SwiftJavaScript.JSVirtualMachine,
  @unchecked Sendable
{
  public typealias Context = QJSContext

  public let unownedExecutor: UnownedSerialExecutor

  /// The raw QuickJS runtime. Package-internal: it is an engine reference, so
  /// it must not appear in a public signature; `==`/`hash` still use it.
  package let runtimeRef: OpaquePointer

  private let owner: VMThread.Owner
  /// Retained so registry cleanup jobs can be scheduled without retaining the
  /// VM itself; the `Owner` is what stops the thread.
  private let thread: VMThread

  public convenience init() {
    self.init(thread: VMThread())
  }

  private init(thread: VMThread) {
    let runtimeBits = thread.runAndWait {
      UInt(bitPattern: QJSEngine.makeRuntime())
    }
    guard let runtimeRef = OpaquePointer(bitPattern: runtimeBits) else {
      preconditionFailure("QuickJS could not create runtime")
    }
    self.runtimeRef = runtimeRef
    self.unownedExecutor = thread.unownedExecutor
    self.owner = thread.owner
    self.thread = thread
  }

  /// The engine context for a new `QJSContext`, created on the VM thread:
  /// creating a context mutates the shared runtime, which that thread may be
  /// using for the VM's other contexts. Package-internal: only
  /// `QJSContext.init(virtualMachine:)` and same-package tests call it.
  package func makeContext() -> OpaquePointer? {
    let runtimeBits = UInt(bitPattern: runtimeRef)
    let contextBits = thread.runAndWait { () -> UInt? in
      guard let runtime = OpaquePointer(bitPattern: runtimeBits),
        let context = QJSEngine.makeContext(in: runtime)
      else {
        return nil
      }
      return UInt(bitPattern: context)
    }
    guard let contextBits else { return nil }
    return OpaquePointer(bitPattern: contextBits)
  }

  /// Force a QuickJS cycle collection on the VM thread.
  package func gc() {
    let runtimeBits = UInt(bitPattern: runtimeRef)
    thread.runAndWait {
      guard let runtime = OpaquePointer(bitPattern: runtimeBits) else { return }
      JS_UpdateStackTop(runtime)
      JS_RunGC(runtime)
    }
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
    let runtimeBits = UInt(bitPattern: runtimeRef)
    thread.runAndWait {
      guard let runtime = OpaquePointer(bitPattern: runtimeBits) else { return }
      QJSEngine.releaseRuntime(runtime)
      removeQuickJSClassRecords(in: runtime)
    }
  }

  public static func == (lhs: QJSVirtualMachine, rhs: QJSVirtualMachine) -> Bool {
    lhs.runtimeRef == rhs.runtimeRef
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(UInt(bitPattern: runtimeRef))
  }
}
