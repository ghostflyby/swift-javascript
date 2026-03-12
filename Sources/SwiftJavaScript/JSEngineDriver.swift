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

package extension _JSEngineDriver where RawRuntime: Sendable, RawContext: Sendable, RawValue: Sendable {
  static func makeRuntimeHandle() -> JSRuntimeHandle<Engine> {
    JSRuntimeHandle<Engine>(_opaqueHandle: makeRuntime())
  }

  static func makeBorrowedContextHandleFromRuntime(
    _ runtime: JSRuntimeHandle<Engine>
  ) -> JSBorrowedContextHandle<Engine>? {
    guard let rawRuntime: RawRuntime = runtime.opaqueHandle() else {
      return nil
    }
    return JSBorrowedContextHandle<Engine>(_opaqueHandle: makeContext(in: rawRuntime))
  }

  static func makeStringValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeString(value, in: rawContext))
  }

  static func makeNumberValueHandle(
    _ value: Double,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeNumber(value, in: rawContext))
  }

  static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeBoolean(value, in: rawContext))
  }

  static func evaluateScriptResultHandle(
    _ script: String,
    _ context: JSBorrowedContextHandle<Engine>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(
      from: evaluateScript(
        script,
        in: rawContext,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }

  static func propertyNamesForHandle(
    _ object: JSValueHandle<Engine>,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> [String]? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return propertyNames(on: rawObject, in: rawContext)
  }

  static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return resultHandle(from: getProperty(key, on: rawObject, in: rawContext))
  }

  static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    _ value: JSValueHandle<Engine>,
    _ context: JSBorrowedContextHandle<Engine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(key, on: rawObject, to: rawValue, in: rawContext, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  private static func resultHandle(from result: JSDriverResult<RawValue>) -> JSResultHandle<Engine> {
    switch result {
    case .value(let rawValue):
      return .value(JSValueHandle<Engine>(_opaqueHandle: rawValue))
    case .exception(let rawValue):
      return .exception(JSValueHandle<Engine>(_opaqueHandle: rawValue))
    }
  }
}
