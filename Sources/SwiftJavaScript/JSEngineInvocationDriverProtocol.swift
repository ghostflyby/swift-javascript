public protocol _JSEngineInvocationDriver: _JSEngineRuntimeDriver {
  static func callFunctionHandle(
    _ function: ValueHandle,
    this thisValue: ValueHandle?,
    arguments: [ValueHandle],
    in context: ContextHandle
  ) -> JSResultPayload<ValueHandle>?

  static func constructHandle(
    _ constructor: ValueHandle,
    arguments: [ValueHandle],
    in context: ContextHandle
  ) -> JSResultPayload<ValueHandle>?

  static func toObjectHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSResultPayload<ValueHandle>?

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
}
