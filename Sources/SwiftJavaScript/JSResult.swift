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
