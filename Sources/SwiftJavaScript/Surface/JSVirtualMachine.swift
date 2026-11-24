/// The virtual machine that owns a JS runtime and its dedicated executor.
///
/// The concrete type is the engine's VM (`JSCVirtualMachine`,
/// `QJSVirtualMachine`); core keeps the shared `VMThread` scheduling that
/// serializes every engine access on the VM thread.
public protocol JSVirtualMachine: AnyObject, Sendable, Hashable {
  /// The context type this VM creates.
  associatedtype Context: JSContext
  where Context.VirtualMachine == Self
  /// The context identity type contexts of this VM are addressed through.
  associatedtype ContextHandle: JSContextRuntimeDriver
  where ContextHandle == Context.ContextHandle
  /// The runtime identity this VM addresses its engine through. Hashable
  /// because runtime identity is a user-facing notion (the VM is `Hashable`).
  associatedtype RuntimeHandle: JSRuntimeManualReferenceCountedHandle & Hashable

  /// Create a VM with a fresh engine runtime and its own VM thread.
  init()

  /// The runtime identity this VM addresses its engine through.
  var driverRuntimeHandle: RuntimeHandle { get }

  /// The VM's dedicated serial executor. Contexts of this VM are actors on
  /// it, so every engine access is serialized on one OS thread.
  var unownedExecutor: UnownedSerialExecutor { get }

  /// Create the engine context for a new `Context` on the VM thread: creating
  /// a context mutates the shared runtime, which that thread may be using for
  /// the VM's other contexts.
  func makeContextHandle() -> ContextHandle?
}
