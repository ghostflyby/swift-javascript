package protocol _JSEngineInvocationDriver: _JSEngineRuntimeDriver {
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
