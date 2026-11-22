/// Context-side invocation operations (Stage 2B decomposition).
public protocol JSContextInvocationDriver: JSContextRuntimeDriver {
  func callFunctionHandle(
    _ function: ValueHandle,
    this thisValue: ValueHandle?,
    arguments: [ValueHandle]
  ) -> JSResult<ValueHandle>?

  func constructHandle(
    _ constructor: ValueHandle,
    arguments: [ValueHandle]
  ) -> JSResult<ValueHandle>?

  func toObjectHandle(_ value: ValueHandle) -> JSResult<ValueHandle>?

  func isArrayHandle(_ value: ValueHandle) -> Bool?

  func isDateHandle(_ value: ValueHandle) -> Bool?

  func isInstanceOfHandle(
    _ value: ValueHandle,
    constructor: ValueHandle
  ) -> Bool?

  func looselyEqualsHandle(
    _ lhs: ValueHandle,
    _ rhs: ValueHandle
  ) -> Bool?

  func strictlyEqualsHandle(
    _ lhs: ValueHandle,
    _ rhs: ValueHandle
  ) -> Bool?
}

/// Engine-side descriptor. Invocation requirements now live on
/// `JSContextInvocationDriver`, implemented by `ContextHandle`.
public protocol JSEngineInvocationDriver: JSEngineRuntimeDriver
where ContextHandle: JSContextInvocationDriver {}
