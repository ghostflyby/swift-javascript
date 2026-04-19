/// Minimal JavaScript value mapping.
///
/// `JSValue` intentionally does not retain a context reference.
/// It only carries the minimal value identity/representation and relies on
/// explicit `in context` parameters at operation sites.
public struct JSValue<E: JSEngine>: ~Copyable {
  var storage: JSValueStorage

  var handle: JSValueHandle<E> {
    get {
      .init(storage: storage)
    }
    set {
      newValue.bindToStorage(&storage)
    }
  }

  public func borrowHandle() -> JSValueHandle<E> {
    handle
  }

  public init(handleValue: JSValueHandle<E>) {
    self.storage = JSValueStorage()
    handle = handleValue
  }

  public init(retaining value: borrowing JSValue<E>) {
    self.init(handleValue: value.retainHandle())
  }

  deinit {
    handle.releaseReference()
  }

  public consuming func discard() {
    discard self
  }

  public consuming func takeHandle() -> JSValueHandle<E> {
    let h = handle
    discard self
    return h
  }

  public func retainHandle() -> JSValueHandle<E> {
    let h = handle
    _ = h.retainReference()
    return h
  }
}
