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

extension _JSEngineDriver where RawRuntime: Sendable, RawContext: Sendable, RawValue: Sendable {
  package static func makeRuntimeHandle() -> JSRuntimeHandle<Engine> {
    JSRuntimeHandle<Engine>(_opaqueHandle: makeRuntime())
  }

  package static func makeBorrowedContextHandleFromRuntime(
    in runtime: JSRuntimeHandle<Engine>
  ) -> JSBorrowedContextHandle<Engine>? {
    guard let rawRuntime: RawRuntime = runtime.opaqueHandle() else {
      return nil
    }
    return JSBorrowedContextHandle<Engine>(_opaqueHandle: makeContext(in: rawRuntime))
  }

  package static func makeStringValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeString(value, in: rawContext))
  }

  package static func makeNumberValueHandle(
    _ value: Double,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeNumber(value, in: rawContext))
  }

  package static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeBoolean(value, in: rawContext))
  }

  package static func makeNullValueHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeNull(in: rawContext))
  }

  package static func makeUndefinedValueHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeUndefined(in: rawContext))
  }

  package static func makeObjectResultHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: makeObject(in: rawContext))
  }

  package static func makeArrayResultHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: makeArray(in: rawContext))
  }

  package static func evaluateScriptResultHandle(
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

  package static func propertyNamesForHandle(
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> [String]? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return propertyNames(on: rawObject, in: rawContext)
  }

  package static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return resultHandle(from: getProperty(key, on: rawObject, in: rawContext))
  }

  package static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>,
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

  package static func callFunctionHandle(
    _ function: JSValueHandle<Engine>,
    this thisValue: JSValueHandle<Engine>? = nil,
    arguments: [JSValueHandle<Engine>] = [],
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawFunction: RawValue = function.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    let rawThisValue: RawValue? = thisValue?.opaqueHandle()
    let rawArguments = arguments.compactMap { $0.opaqueHandle(as: RawValue.self) }
    guard rawArguments.count == arguments.count else {
      return nil
    }

    return resultHandle(
      from: callFunction(rawFunction, this: rawThisValue, arguments: rawArguments, in: rawContext)
    )
  }

  package static func constructHandle(
    _ constructor: JSValueHandle<Engine>,
    arguments: [JSValueHandle<Engine>] = [],
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawConstructor: RawValue = constructor.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    let rawArguments = arguments.compactMap { $0.opaqueHandle(as: RawValue.self) }
    guard rawArguments.count == arguments.count else {
      return nil
    }

    return resultHandle(from: construct(rawConstructor, arguments: rawArguments, in: rawContext))
  }

  package static func toObjectHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    return resultHandle(from: toObject(rawValue, in: rawContext))
  }

  package static func isArrayHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isArray(rawValue, in: rawContext)
  }

  package static func isDateHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isDate(rawValue, in: rawContext)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueHandle<Engine>,
    constructor: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawConstructor: RawValue = constructor.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isInstanceOf(rawValue, constructor: rawConstructor, in: rawContext)
  }

  private static func resultHandle(from result: JSDriverResult<RawValue>) -> JSResultHandle<Engine>
  {
    switch result {
    case .value(let rawValue):
      return .value(JSValueHandle<Engine>(_opaqueHandle: rawValue))
    case .exception(let rawValue):
      return .exception(JSValueHandle<Engine>(_opaqueHandle: rawValue))
    }
  }
}
