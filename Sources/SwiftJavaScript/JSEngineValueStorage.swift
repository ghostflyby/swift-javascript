public struct JSEngineValueStorage<E: JSEngine>: ~Copyable {
  let handle: JSValueHandle<E>

  public init(handle: JSValueHandle<E>) {
    self.handle = handle
  }

  public func valueHandle() -> JSValueHandle<E> {
    handle
  }
}
