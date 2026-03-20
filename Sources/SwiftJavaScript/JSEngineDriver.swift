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

  package static func makeSymbolValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeSymbol(value, in: rawContext))
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

  package static func getValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return resultHandle(from: getProperty(rawKey, on: rawObject, in: rawContext))
  }

  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return resultHandle(from: getProperty(at: index, on: rawObject, in: rawContext))
  }

  package static func setValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(rawKey, on: rawObject, to: rawValue, in: rawContext, attributes: attributes)
    {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(at: index, on: rawObject, to: rawValue, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return hasProperty(key, on: rawObject, in: rawContext)
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return hasProperty(rawKey, on: rawObject, in: rawContext)
  }

  package static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch deleteProperty(key, on: rawObject, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func deleteValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch deleteProperty(rawKey, on: rawObject, in: rawContext) {
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
