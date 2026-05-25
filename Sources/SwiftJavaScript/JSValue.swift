/// Minimal JavaScript value mapping.
///
/// `JSValue` intentionally does not retain a context reference.
/// It only carries the minimal value identity/representation and relies on
/// explicit `in context` parameters at operation sites.
public struct JSValue<E: JSEngine>: ~Copyable {
  let storage: JSValueStorageWords

  package var handle: JSValueHandle<E> {
    E.fromStorageWords(storage).0
  }
  package var contextHandle: E.ContextHandle {
    return E.fromStorageWords(storage).1
  }

  public func borrowHandle() -> JSValueHandle<E> {
    handle
  }

  package init(handleValue: JSValueHandle<E>, in context: E.ContextHandle) {
    self.storage = E.makeStorageWords(value: handleValue, in: context)
  }

  public init(retaining value: borrowing JSValue<E>) {
    self.init(handleValue: value.retainHandle(), in: value.contextHandle)
  }

  deinit {
    handle.releaseReference(in: contextHandle)
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
    h.retainReference(in: contextHandle)
    return h
  }
}
