public protocol JSEngineInvocationDriver: JSEngineRuntimeDriver {
  @_lifetime(immortal)
  static func callFunctionHandle(
    _ function: ValueHandle,
    this thisValue: ValueHandle?,
    arguments: [ValueHandle],
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  @_lifetime(immortal)
  static func constructHandle(
    _ constructor: ValueHandle,
    arguments: [ValueHandle],
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  @_lifetime(immortal)
  static func toObjectHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func isArrayHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func isDateHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func isInstanceOfHandle(
    _ value: ValueHandle,
    constructor: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func looselyEqualsHandle(
    _ lhs: ValueHandle,
    _ rhs: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func strictlyEqualsHandle(
    _ lhs: ValueHandle,
    _ rhs: ValueHandle,
    in context: ContextHandle
  ) -> Bool?
}
