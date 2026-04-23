public enum JSResult<Value: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
  case value(Value)
  case exception(Value)
}

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

@_lifetime(copy result)
package func takeExceptionValue<Value: ~Copyable & ~Escapable>(
  _ result: consuming JSResult<Value>
) -> Value? {
  switch consume result {
  case .value:
    return nil
  case .exception(let exception):
    return exception
  }
}

@_lifetime(immortal)
public func bridgeHandleResult<E: JSEngine>(
  _ handleResult: consuming JSResult<JSValueHandle<E>>?
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

@_lifetime(immortal)
package func retainResult<E: JSEngine>(
  _ result: consuming JSResult<JSValue<E>>
) -> JSResult<JSValue<E>> {
  switch consume result {
  case .value(let value):
    return .value(JSValue(retaining: value))
  case .exception(let exception):
    return .exception(JSValue(retaining: exception))
  }
}

@_lifetime(immortal)
package func retainOptionalValue<E: JSEngine>(
  _ value: consuming JSValue<E>?
) -> JSValue<E>? {
  guard let value else {
    return nil
  }
  return JSValue(retaining: value)
}
