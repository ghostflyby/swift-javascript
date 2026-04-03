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
