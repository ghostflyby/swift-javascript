import JavaScriptCore

// MARK: - Surface result bridge (S4)
//
// The class
// callbacks now hand `JSResult<JSCValue>` to the private ABI.

extension JSResult where Value == JSCValue {
  borrowing func toPrivateResult() -> JSResult<JSValueRef> {
    switch self {
    case .value(let v):
      return .value(v.borrowedRef())
    case .exception(let e):
      return .exception(e.borrowedRef())
    }
  }
}
