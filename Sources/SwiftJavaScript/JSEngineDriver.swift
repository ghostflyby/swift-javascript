package enum JSDriverResult<Value> {
  case value(Value)
  case exception(Value)
}

package protocol _JSEngineDriver {
  associatedtype Engine: JSEngine
  associatedtype RawRuntime
  associatedtype RawContext
  associatedtype RawValue

  static var capabilities: JSEngineCapabilities { get }

  static func makeRuntime() -> RawRuntime
  static func makeContext(in runtime: RawRuntime) -> RawContext

  static func evaluateScript(
    _ script: String,
    in context: RawContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSDriverResult<RawValue>

  static func makeString(_ value: String, in context: RawContext) -> RawValue
  static func makeNumber(_ value: Double, in context: RawContext) -> RawValue
  static func makeBoolean(_ value: Bool, in context: RawContext) -> RawValue
  static func makeNull(in context: RawContext) -> RawValue
  static func makeUndefined(in context: RawContext) -> RawValue
  static func makeObject(in context: RawContext) -> JSDriverResult<RawValue>
  static func makeArray(in context: RawContext) -> JSDriverResult<RawValue>

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
