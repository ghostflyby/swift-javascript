public struct JSRuntimeHandle<E: JSEngine> {
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

public struct JSBorrowedContextHandle<E: JSEngine> {
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

public struct JSValueHandle<E: JSEngine> {
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

public enum JSResultHandle<E: JSEngine> {
  case value(JSValueHandle<E>)
  case exception(JSValueHandle<E>)

  public var isException: Bool {
    switch self {
    case .value:
      return false
    case .exception:
      return true
    }
  }
}
