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

/// Bridge an engine operation result into a non-owning `JSValue` view.
///
/// `JSValue` owns nothing (§3.2), so the engine's result reference is adopted
/// by the context default scope arena (stack bottom, rooted per policy §3.7)
/// before the view is returned. This is the `JSValue` counterpart of
/// `bridgeCallbackResult`, which tracks on the current synchronous frame.
public func bridgeHandleResult<E: JSEngineRuntimeDriver>(
  _ handleResult: JSResult<JSValueHandle<E>>?,
  in context: E.ContextHandle
) -> JSResult<JSValue<E>> {
  guard let handleResult else {
    preconditionFailure("JSResult handle bridge unexpectedly returned nil")
  }

  switch handleResult {
  case .value(let value):
    return .value(adoptCreatedValueHandle(value, in: context))
  case .exception(let exception):
    return .exception(adoptCreatedValueHandle(exception, in: context))
  }
}
