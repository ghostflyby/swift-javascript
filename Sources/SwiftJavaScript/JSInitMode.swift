/// The non-blocking initialization marker.
///
/// Synchronous and `async` initializers cannot share a signature, so the
/// non-blocking variants take this marker argument:
///
///     let vm = await JSCVirtualMachine(.nonblocking)
///     let context = await JSCContext(virtualMachine: vm, .nonblocking)
public enum JSInitMode: Sendable {
  /// Await engine initialization on the VM executor instead of blocking the
  /// calling thread.
  case nonblocking
}
