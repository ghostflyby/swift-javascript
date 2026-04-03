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

extension _JSEngineInvocationDriver {
  public static func callFunctionHandle(
    _ function: ValueHandle,
    this thisValue: ValueHandle?,
    arguments: [ValueHandle],
    in context: ContextHandle
  ) -> JSResultPayload<ValueHandle>? {
    fatalError(
      "_JSEngineInvocationDriver.callFunctionHandle(_:this:arguments:in:) is not implemented")
  }

  public static func constructHandle(
    _ constructor: ValueHandle,
    arguments: [ValueHandle],
    in context: ContextHandle
  ) -> JSResultPayload<ValueHandle>? {
    fatalError("_JSEngineInvocationDriver.constructHandle(_:arguments:in:) is not implemented")
  }

  public static func toObjectHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSResultPayload<ValueHandle>? {
    fatalError("_JSEngineInvocationDriver.toObjectHandle(_:in:) is not implemented")
  }

  public static func isArrayHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool? {
    fatalError("_JSEngineInvocationDriver.isArrayHandle(_:in:) is not implemented")
  }

  public static func isDateHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool? {
    fatalError("_JSEngineInvocationDriver.isDateHandle(_:in:) is not implemented")
  }

  public static func isInstanceOfHandle(
    _ value: ValueHandle,
    constructor: ValueHandle,
    in context: ContextHandle
  ) -> Bool? {
    fatalError(
      "_JSEngineInvocationDriver.isInstanceOfHandle(_:constructor:in:) is not implemented")
  }
}
