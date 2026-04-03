public struct JSValueHandle<E: JSEngine>: @unchecked Sendable {
  package let storage: _JSOpaqueHandleStorage

  package init(_opaqueHandle: any Sendable) {
    self.storage = _JSOpaqueHandleStorage(base: _opaqueHandle)
  }

  public var engineType: E.Type {
    E.self
  }

  package func opaqueHandle<T>(as type: T.Type = T.self) -> T? {
    storage.base as? T
  }
}
