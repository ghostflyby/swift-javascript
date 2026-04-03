public enum JSResultPayload<Value: ~Copyable>: ~Copyable {
  case value(Value)
  case exception(Value)
}

extension JSResultPayload: Copyable where Value: Copyable {}

extension JSResultPayload {
  public var isException: Bool {
    switch self {
    case .value:
      return false
    case .exception:
      return true
    }
  }
}

public func bridgeHandleResult<E: JSEngine>(
  _ handleResult: JSResultPayload<JSValueHandle<E>>?
) -> JSResultPayload<JSEngineValue<E>> {
  guard let handleResult else {
    preconditionFailure("JSResult handle bridge unexpectedly returned nil")
  }

  switch handleResult {
  case .value(let value):
    return .value(JSEngineValue(storage: JSEngineValueStorage(handle: value)))
  case .exception(let exception):
    return .exception(JSEngineValue(storage: JSEngineValueStorage(handle: exception)))
  }
}
