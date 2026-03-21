package protocol _JSEnginePropertyDriver: _JSEngineRuntimeDriver {
  static func propertyNames(
    on object: RawValue,
    in context: RawContext
  ) -> [String]

  static func getProperty(
    _ key: String,
    on object: RawValue,
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func getProperty(
    _ key: RawValue,
    on object: RawValue,
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func getProperty(
    at index: UInt32,
    on object: RawValue,
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func hasProperty(
    _ key: String,
    on object: RawValue,
    in context: RawContext
  ) -> Bool

  static func hasProperty(
    _ key: RawValue,
    on object: RawValue,
    in context: RawContext
  ) -> Bool

  static func deleteProperty(
    _ key: String,
    on object: RawValue,
    in context: RawContext
  ) -> JSDriverResult<Void>

  static func deleteProperty(
    _ key: RawValue,
    on object: RawValue,
    in context: RawContext
  ) -> JSDriverResult<Void>

  static func setProperty(
    _ key: String,
    on object: RawValue,
    to value: RawValue,
    in context: RawContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void>

  static func setProperty(
    _ key: RawValue,
    on object: RawValue,
    to value: RawValue,
    in context: RawContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void>

  static func setProperty(
    at index: UInt32,
    on object: RawValue,
    to value: RawValue,
    in context: RawContext
  ) -> JSDriverResult<Void>
}
