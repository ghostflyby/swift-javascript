public enum JSResult<Value: ~Copyable>: ~Copyable {
  case value(Value)
  case exception(Value)
}

extension JSResult: Copyable where Value: Copyable {}

extension JSResult {
  public var isException: Bool {
    switch self {
    case .value:
      return false
    case .exception:
      return true
    }
  }

}

package func takeExceptionValue<Value: ~Copyable>(
  _ result: consuming JSResult<Value>
) -> Value? {
  switch consume result {
  case .value:
    return nil
  case .exception(let exception):
    return exception
  }
}

public func bridgeHandleResult<E: JSEngine>(
  _ handleResult: JSResult<JSValueHandle<E>>?
) -> JSResult<JSValue<E>> {
  guard let handleResult else {
    preconditionFailure("JSResult handle bridge unexpectedly returned nil")
  }

  switch handleResult {
  case .value(let value):
    return .value(JSValue(handleValue: value))
  case .exception(let exception):
    return .exception(JSValue(handleValue: exception))
  }
}
