/// Minimal JavaScript value mapping.
///
/// `JSValue` intentionally does not retain a context reference.
/// It only carries the minimal value identity/representation and relies on
/// explicit `in context` parameters at operation sites.
public struct JSValue<E: JSEngine>: ~Copyable {
  package let _rawValue: JSValueHandle<E>

  public init(handleValue: JSValueHandle<E>) {
    self._rawValue = handleValue
  }

  public func valueHandle() -> JSValueHandle<E> {
    _rawValue
  }

  deinit {
    _ = _rawValue.releaseReference()
  }
}
