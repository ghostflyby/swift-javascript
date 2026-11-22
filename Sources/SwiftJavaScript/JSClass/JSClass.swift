public typealias JSClassHandle<E: JSEngineRuntimeDriver> = E.ClassHandle

public final class JSClass<E: JSEngineRuntimeDriver>: @unchecked Sendable {
  package let _rawValue: JSClassHandle<E>
  package let retainedOwner: AnyObject?

  public init(handleClass: JSClassHandle<E>, retainedOwner: AnyObject? = nil) {
    self._rawValue = handleClass
    self.retainedOwner = retainedOwner
    _ = handleClass.retainReference()
  }

  package init(adoptingHandleClass: JSClassHandle<E>, retainedOwner: AnyObject? = nil) {
    self._rawValue = adoptingHandleClass
    self.retainedOwner = retainedOwner
  }

  deinit {
    _ = _rawValue.releaseReference()
  }

  public func classHandle() -> JSClassHandle<E> {
    _rawValue
  }
}

extension JSClass: Equatable where E.ClassHandle: Equatable {
  public static func == (lhs: JSClass<E>, rhs: JSClass<E>) -> Bool {
    lhs.classHandle() == rhs.classHandle()
  }
}

extension JSClass: Hashable where E.ClassHandle: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(classHandle())
  }
}
