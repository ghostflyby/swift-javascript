public protocol _JSEngineInvocationDriver: _JSEngineRuntimeDriver {
  static func callFunction(
    _ function: RawValue,
    this thisValue: RawValue?,
    arguments: [RawValue],
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func construct(
    _ constructor: RawValue,
    arguments: [RawValue],
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func toObject(
    _ value: RawValue,
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func isArray(
    _ value: RawValue,
    in context: RawContext
  ) -> Bool

  static func isDate(
    _ value: RawValue,
    in context: RawContext
  ) -> Bool

  static func isInstanceOf(
    _ value: RawValue,
    constructor: RawValue,
    in context: RawContext
  ) -> Bool
}

extension _JSEngineInvocationDriver {
  public static func callFunction(
    _ function: RawValue,
    this thisValue: RawValue?,
    arguments: [RawValue],
    in context: RawContext
  ) -> JSDriverResult<RawValue> {
    fatalError("_JSEngineInvocationDriver.callFunction(_:this:arguments:in:) is not implemented")
  }

  public static func construct(
    _ constructor: RawValue,
    arguments: [RawValue],
    in context: RawContext
  ) -> JSDriverResult<RawValue> {
    fatalError("_JSEngineInvocationDriver.construct(_:arguments:in:) is not implemented")
  }

  public static func toObject(
    _ value: RawValue,
    in context: RawContext
  ) -> JSDriverResult<RawValue> {
    fatalError("_JSEngineInvocationDriver.toObject(_:in:) is not implemented")
  }

  public static func isArray(
    _ value: RawValue,
    in context: RawContext
  ) -> Bool {
    fatalError("_JSEngineInvocationDriver.isArray(_:in:) is not implemented")
  }

  public static func isDate(
    _ value: RawValue,
    in context: RawContext
  ) -> Bool {
    fatalError("_JSEngineInvocationDriver.isDate(_:in:) is not implemented")
  }

  public static func isInstanceOf(
    _ value: RawValue,
    constructor: RawValue,
    in context: RawContext
  ) -> Bool {
    fatalError("_JSEngineInvocationDriver.isInstanceOf(_:constructor:in:) is not implemented")
  }
}
