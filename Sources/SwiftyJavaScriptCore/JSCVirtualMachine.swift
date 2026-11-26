import JavaScriptCore
import SwiftJavaScript

/// The JavaScriptCore virtual machine: one context group plus the dedicated
/// VM thread every context of this VM runs on.
///
/// Engine access only happens on that thread (design §0.2.3): the runtime is
/// created there, every context handle is created there, and the runtime is
/// released there. `nonisolated ==`/`hash` use the runtime handle, so a
/// dropped VM can still be identified without touching the engine.
public final class JSCVirtualMachine: SwiftJavaScript.JSVirtualMachine,
  @unchecked Sendable
{
  public typealias Context = JSCContext

  public let unownedExecutor: UnownedSerialExecutor

  /// This VM's JavaScriptCore context group. Package-internal: the raw
  /// reference is an implementation detail and must not appear in a public
  /// signature; `==`/`hash` still use it.
  package let groupRef: JSContextGroupRef

  private let owner: VMThread.Owner
  /// Retained so registry cleanup jobs can be scheduled without retaining the
  /// VM itself; the `Owner` is what stops the thread.
  private let thread: VMThread

  public convenience init() {
    self.init(thread: VMThread())
  }

  private init(thread: VMThread) {
    let groupBits = thread.runAndWait {
      UInt(bitPattern: JSCEngine.makeRuntime())
    }
    guard let groupRef = JSContextGroupRef(bitPattern: groupBits) else {
      preconditionFailure("JavaScriptCore could not create a context group")
    }
    self.groupRef = groupRef
    self.unownedExecutor = thread.unownedExecutor
    self.owner = thread.owner
    self.thread = thread
  }

  /// The engine context for a new `JSCContext`, created on the VM thread:
  /// creating a context mutates the shared runtime, which that thread may be
  /// using for the VM's other contexts. Package-internal: only
  /// `JSCContext.init(virtualMachine:)` and same-package tests call it.
  package func makeContextHandle() -> JSGlobalContextRef? {
    let groupBits = UInt(bitPattern: groupRef)
    let contextBits = thread.runAndWait { () -> UInt? in
      guard let groupRef = JSContextGroupRef(bitPattern: groupBits) else {
        return nil
      }
      guard
        let contextRef = JSCEngine.makeBorrowedContextHandleFromRuntime(in: groupRef)
      else {
        return nil
      }
      return UInt(bitPattern: contextRef)
    }
    guard let contextBits else { return nil }
    return JSGlobalContextRef(bitPattern: contextBits)
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
    let groupBits = UInt(bitPattern: groupRef)
    thread.runAndWait {
      if let groupRef = JSContextGroupRef(bitPattern: groupBits) {
        JSCEngine.releaseRuntime(groupRef)
      }
    }
  }

  public static func == (lhs: JSCVirtualMachine, rhs: JSCVirtualMachine) -> Bool {
    lhs.groupRef == rhs.groupRef
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(UInt(bitPattern: groupRef))
  }
}
