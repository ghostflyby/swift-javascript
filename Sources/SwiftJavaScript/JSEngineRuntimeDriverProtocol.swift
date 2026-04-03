public protocol _JSEngineRuntimeDriver {
  associatedtype Engine: JSEngine = Self
  associatedtype RawRuntime = Never
  associatedtype RawContext = Never
  associatedtype RawValue = Never

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
  static func makeSymbol(_ value: String, in context: RawContext) -> RawValue
  static func makeNumber(_ value: Double, in context: RawContext) -> RawValue
  static func makeBoolean(_ value: Bool, in context: RawContext) -> RawValue
  static func makeNull(in context: RawContext) -> RawValue
  static func makeUndefined(in context: RawContext) -> RawValue
  static func makeObject(in context: RawContext) -> JSDriverResult<RawValue>
  static func makeArray(in context: RawContext) -> JSDriverResult<RawValue>
}

extension _JSEngineRuntimeDriver {
  public static var capabilities: JSEngineCapabilities { .init() }

  public static func makeRuntime() -> RawRuntime {
    fatalError("_JSEngineRuntimeDriver.makeRuntime() is not implemented")
  }

  public static func makeContext(in runtime: RawRuntime) -> RawContext {
    fatalError("_JSEngineRuntimeDriver.makeContext(in:) is not implemented")
  }

  public static func evaluateScript(
    _ script: String,
    in context: RawContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSDriverResult<RawValue> {
    fatalError(
      "_JSEngineRuntimeDriver.evaluateScript(_:in:sourceURL:startingLineNumber:) is not implemented"
    )
  }

  public static func makeString(_ value: String, in context: RawContext) -> RawValue {
    fatalError("_JSEngineRuntimeDriver.makeString(_:in:) is not implemented")
  }

  public static func makeSymbol(_ value: String, in context: RawContext) -> RawValue {
    fatalError("_JSEngineRuntimeDriver.makeSymbol(_:in:) is not implemented")
  }

  public static func makeNumber(_ value: Double, in context: RawContext) -> RawValue {
    fatalError("_JSEngineRuntimeDriver.makeNumber(_:in:) is not implemented")
  }

  public static func makeBoolean(_ value: Bool, in context: RawContext) -> RawValue {
    fatalError("_JSEngineRuntimeDriver.makeBoolean(_:in:) is not implemented")
  }

  public static func makeNull(in context: RawContext) -> RawValue {
    fatalError("_JSEngineRuntimeDriver.makeNull(in:) is not implemented")
  }

  public static func makeUndefined(in context: RawContext) -> RawValue {
    fatalError("_JSEngineRuntimeDriver.makeUndefined(in:) is not implemented")
  }

  public static func makeObject(in context: RawContext) -> JSDriverResult<RawValue> {
    fatalError("_JSEngineRuntimeDriver.makeObject(in:) is not implemented")
  }

  public static func makeArray(in context: RawContext) -> JSDriverResult<RawValue> {
    fatalError("_JSEngineRuntimeDriver.makeArray(in:) is not implemented")
  }
}
