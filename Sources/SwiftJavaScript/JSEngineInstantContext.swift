/// Engine-agnostic instant context shell.
///
/// Concrete engines provide API surface and bridge behaviors in facade
/// modules via constrained extensions.
public struct JSEngineInstantContext<E: JSEngine>: ~Copyable {
  public let driverContextHandle: E.ContextHandle

  package init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
  }
}
