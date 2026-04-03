/// Engine-agnostic JavaScript value shell.
///
/// Concrete engines provide API surface and bridge behaviors in their facade
/// modules via constrained extensions.
public struct JSEngineValue<E: JSEngine>: ~Copyable {
  package let _rawValue: JSEngineValueStorage<E>

  package init(storage: consuming JSEngineValueStorage<E>) {
    self._rawValue = storage
  }
}
