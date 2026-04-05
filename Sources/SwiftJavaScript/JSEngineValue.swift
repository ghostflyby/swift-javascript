/// Engine-agnostic JavaScript value shell.
///
/// Concrete engines provide API surface and bridge behaviors in their facade
/// modules via constrained extensions.
public struct JSEngineValue<E: JSEngine>: ~Copyable {
  package let _rawValue: JSValueHandle<E>

  public init(handleValue: JSValueHandle<E>) {
    self._rawValue = handleValue
  }

  public func valueHandle() -> JSValueHandle<E> {
    _rawValue
  }
}
