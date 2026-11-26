/// The virtual machine that owns a JS runtime and its dedicated executor.
///
/// The concrete type is the engine's VM (`JSCVirtualMachine`,
/// `QJSVirtualMachine`); core keeps the shared `VMThread` scheduling that
/// serializes every engine access on the VM thread. Runtime and context
/// creation are engine-internal: the concrete VM exposes them to the package,
/// and the concrete context's `init(virtualMachine:)` is their only call site.
public protocol JSVirtualMachine: AnyObject, Sendable, Hashable {
  /// The context type this VM creates.
  associatedtype Context: JSContext
  where Context.VirtualMachine == Self

  /// Create a VM with a fresh engine runtime and its own VM thread.
  init()

  /// The VM's dedicated serial executor. Contexts of this VM are actors on
  /// it, so every engine access is serialized on one OS thread.
  var unownedExecutor: UnownedSerialExecutor { get }
}
