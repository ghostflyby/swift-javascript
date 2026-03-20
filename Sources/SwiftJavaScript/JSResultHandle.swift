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
