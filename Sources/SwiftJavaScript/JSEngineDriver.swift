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

  static func getProperty(
    _ key: String,
    on object: RawValue,
    in context: RawContext
  ) -> JSDriverResult<RawValue>

  static func setProperty(
    _ key: String,
    on object: RawValue,
    to value: RawValue,
    in context: RawContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void>
}
