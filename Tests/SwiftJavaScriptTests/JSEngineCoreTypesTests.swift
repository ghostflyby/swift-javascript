import Testing

@testable import SwiftJavaScript

private struct MockRuntime: Sendable, Equatable {
  let id: String
}

private struct MockContext: Sendable, Equatable {
  let runtimeID: String
}

private struct MockValue: Sendable, Equatable {
  let kind: String
  let payload: String
}

private struct MockValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  typealias Engine = MockEngine
  typealias RawValue = MockValue

  let rawValue: MockValue

  init(rawValue: MockValue) {
    self.rawValue = rawValue
  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  func retainReference() -> Bool {
    true
  }

  func releaseReference() -> Bool {
    true
  }
}

private enum MockEngine: JSEngine {
  typealias ValueHandle = MockValueHandle
}

private enum MockDriver: JSEngine {
  typealias ValueHandle = MockValueHandle
  typealias Engine = MockEngine
  typealias RawRuntime = MockRuntime
  typealias RawContext = MockContext
  typealias RawValue = MockValue

  static let capabilities = JSEngineCapabilities(supportsHostObjects: true)

  static func makeRuntime() -> MockRuntime {
    MockRuntime(id: "runtime")
  }

  static func makeContext(in runtime: MockRuntime) -> MockContext {
    MockContext(runtimeID: runtime.id)
  }

  static func evaluateScript(
    _ script: String,
    in context: MockContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSDriverResult<MockValue> {
    if script == "throw" {
      return .exception(MockValue(kind: "exception", payload: "\(context.runtimeID):throw"))
    }
    return .value(MockValue(kind: "script", payload: "\(context.runtimeID):\(script)"))
  }

  static func makeString(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "string", payload: "\(context.runtimeID):\(value)")
  }

  static func makeSymbol(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "symbol", payload: "\(context.runtimeID):\(value)")
  }

  static func makeNumber(_ value: Double, in context: MockContext) -> MockValue {
    MockValue(kind: "number", payload: "\(context.runtimeID):\(value)")
  }

  static func makeBoolean(_ value: Bool, in context: MockContext) -> MockValue {
    MockValue(kind: "boolean", payload: "\(context.runtimeID):\(value)")
  }

  static func makeNull(in context: MockContext) -> MockValue {
    MockValue(kind: "null", payload: context.runtimeID)
  }

  static func makeUndefined(in context: MockContext) -> MockValue {
    MockValue(kind: "undefined", payload: context.runtimeID)
  }

  static func makeObject(in context: MockContext) -> JSDriverResult<MockValue> {
    .value(MockValue(kind: "object", payload: context.runtimeID))
  }

  static func makeArray(in context: MockContext) -> JSDriverResult<MockValue> {
    .value(MockValue(kind: "array", payload: context.runtimeID))
  }

  static func propertyNames(on object: MockValue, in context: MockContext) -> [String] {
    [context.runtimeID, object.kind, object.payload]
  }

  static func getProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSDriverResult<MockValue>
  {
    .value(MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key)"))
  }

  static func getProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSDriverResult<MockValue>
  {
    .value(
      MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key.payload)"))
  }

  static func getProperty(at index: UInt32, on object: MockValue, in context: MockContext)
    -> JSDriverResult<MockValue>
  {
    .value(MockValue(kind: "index", payload: "\(context.runtimeID):\(object.payload):\(index)"))
  }

  static func hasProperty(_ key: String, on object: MockValue, in context: MockContext) -> Bool {
    object.payload.contains(key)
  }

  static func hasProperty(_ key: MockValue, on object: MockValue, in context: MockContext) -> Bool {
    object.payload.contains(key.payload)
  }

  static func deleteProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSDriverResult<Void>
  {
    .value(())
  }

  static func deleteProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSDriverResult<Void>
  {
    .value(())
  }

  static func callFunction(
    _ function: MockValue,
    this thisValue: MockValue?,
    arguments: [MockValue],
    in context: MockContext
  ) -> JSDriverResult<MockValue> {
    .value(
      MockValue(
        kind: "call", payload: "\(context.runtimeID):\(function.payload):\(arguments.count)"))
  }

  static func construct(_ constructor: MockValue, arguments: [MockValue], in context: MockContext)
    -> JSDriverResult<MockValue>
  {
    .value(MockValue(kind: "construct", payload: "\(context.runtimeID):\(arguments.count)"))
  }

  static func toObject(_ value: MockValue, in context: MockContext) -> JSDriverResult<MockValue> {
    .value(MockValue(kind: "object", payload: value.payload))
  }

  static func isArray(_ value: MockValue, in context: MockContext) -> Bool {
    value.kind == "array"
  }

  static func isDate(_ value: MockValue, in context: MockContext) -> Bool {
    value.kind == "date"
  }

  static func isInstanceOf(_ value: MockValue, constructor: MockValue, in context: MockContext)
    -> Bool
  {
    value.payload == constructor.payload
  }

  static func setProperty(
    _ key: String,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void> {
    .value(())
  }

  static func setProperty(
    _ key: MockValue,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void> {
    .value(())
  }

  static func setProperty(
    at index: UInt32, on object: MockValue, to value: MockValue, in context: MockContext
  )
    -> JSDriverResult<Void>
  {
    .value(())
  }
}

extension MockDriver {
  fileprivate static func resultHandle(from result: JSDriverResult<MockValue>) -> JSResultHandle<
    MockEngine
  > {
    switch result {
    case .value(let value):
      return .value(JSValueHandle<MockEngine>(rawValue: value))
    case .exception(let exception):
      return .exception(JSValueHandle<MockEngine>(rawValue: exception))
    }
  }

  fileprivate static func makeRuntimeHandle() -> JSRuntimeHandle<MockEngine> {
    JSRuntimeHandle<MockEngine>(_opaqueHandle: makeRuntime())
  }

  fileprivate static func makeBorrowedContextHandleFromRuntime(
    in runtime: JSRuntimeHandle<MockEngine>
  ) -> JSBorrowedContextHandle<MockEngine>? {
    guard let rawRuntime: MockRuntime = runtime.opaqueHandle() else {
      return nil
    }
    return JSBorrowedContextHandle<MockEngine>(_opaqueHandle: makeContext(in: rawRuntime))
  }

  fileprivate static func makeStringValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<MockEngine>(rawValue: makeString(value, in: rawContext))
  }

  fileprivate static func makeNumberValueHandle(
    _ value: Double,
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<MockEngine>(rawValue: makeNumber(value, in: rawContext))
  }

  fileprivate static func makeSymbolValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<MockEngine>(rawValue: makeSymbol(value, in: rawContext))
  }

  fileprivate static func makeNullValueHandle(
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<MockEngine>(rawValue: makeNull(in: rawContext))
  }

  fileprivate static func makeUndefinedValueHandle(
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<MockEngine>(rawValue: makeUndefined(in: rawContext))
  }

  fileprivate static func makeObjectResultHandle(
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: makeObject(in: rawContext))
  }

  fileprivate static func makeArrayResultHandle(
    _ context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: makeArray(in: rawContext))
  }

  fileprivate static func evaluateScriptResultHandle(
    _ script: String,
    _ context: JSBorrowedContextHandle<MockEngine>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
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

  fileprivate static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> [String]? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return propertyNames(on: object.rawValue, in: rawContext)
  }

  fileprivate static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: getProperty(key, on: object.rawValue, in: rawContext))
  }

  fileprivate static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return false
    }
    switch setProperty(
      key,
      on: object.rawValue,
      to: value.rawValue,
      in: rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: getProperty(key.rawValue, on: object.rawValue, in: rawContext))
  }

  fileprivate static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: getProperty(at: index, on: object.rawValue, in: rawContext))
  }

  fileprivate static func setValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return false
    }
    switch setProperty(
      key.rawValue,
      on: object.rawValue,
      to: value.rawValue,
      in: rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return false
    }
    switch setProperty(at: index, on: object.rawValue, to: value.rawValue, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return hasProperty(key, on: object.rawValue, in: rawContext)
  }

  fileprivate static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return hasProperty(key.rawValue, on: object.rawValue, in: rawContext)
  }

  fileprivate static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return false
    }
    switch deleteProperty(key, on: object.rawValue, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func deleteValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return false
    }
    switch deleteProperty(key.rawValue, on: object.rawValue, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    let rawThisValue: MockValue? = thisValue?.rawValue
    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: callFunction(
        function.rawValue,
        this: rawThisValue,
        arguments: rawArguments,
        in: rawContext
      )
    )
  }

  fileprivate static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: construct(constructor.rawValue, arguments: rawArguments, in: rawContext))
  }

  fileprivate static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> JSResultHandle<MockEngine>? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return resultHandle(from: toObject(value.rawValue, in: rawContext))
  }

  fileprivate static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return isArray(value.rawValue, in: rawContext)
  }

  fileprivate static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return isDate(value.rawValue, in: rawContext)
  }

  fileprivate static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: JSBorrowedContextHandle<MockEngine>
  ) -> Bool? {
    guard let rawContext: MockContext = context.opaqueHandle() else {
      return nil
    }
    return isInstanceOf(value.rawValue, constructor: constructor.rawValue, in: rawContext)
  }
}

@Test func engineCapabilitiesDefaultsToDisabled() {
  let capabilities = JSEngineCapabilities()

  #expect(!capabilities.supportsBigInt)
  #expect(!capabilities.supportsSymbol)
  #expect(!capabilities.supportsExternalArrayBuffer)
  #expect(!capabilities.supportsHostObjects)
  #expect(!capabilities.supportsESModules)
  #expect(!capabilities.supportsPromiseJobQueueControl)
}

@Test func hostModuleDescriptorKeepsTypeMetadata() {
  let descriptor = JSHostModuleDescriptor(
    name: "Console",
    functions: [
      JSHostFunctionDescriptor(name: "log", binding: "console_log")
    ],
    constants: [
      JSHostConstantDescriptor(name: "version", value: "1.0.0")
    ],
    types: [
      JSHostTypeDescriptor(
        name: "Timer",
        constructor: JSHostConstructorDescriptor(binding: "timer_ctor"),
        methods: [JSHostFunctionDescriptor(name: "start", binding: "timer_start")],
        staticMethods: [JSHostFunctionDescriptor(name: "now", binding: "timer_now")],
        properties: [
          JSHostPropertyDescriptor(
            name: "running",
            getterBinding: "timer_get_running",
            setterBinding: "timer_set_running"
          )
        ],
        parent: "EventTarget",
        storagePolicy: .swiftRetainedObject,
        initializerBinding: "timer_initialize",
        finalizerBinding: "timer_finalize",
        dynamicPropertyGetterBinding: "timer_dynamic_get",
        propertyEnumeratorBinding: "timer_dynamic_enumerate",
        callAsFunctionBinding: "timer_call"
      )
    ]
  )

  #expect(descriptor.name == "Console")
  #expect(descriptor.functions.count == 1)
  #expect(descriptor.constants.count == 1)
  #expect(descriptor.types.count == 1)
  #expect(descriptor.types[0].parent == "EventTarget")
  #expect(descriptor.types[0].methods[0].binding == "timer_start")
  #expect(descriptor.types[0].initializerBinding == "timer_initialize")
  #expect(descriptor.types[0].dynamicPropertyGetterBinding == "timer_dynamic_get")
  #expect(descriptor.types[0].propertyEnumeratorBinding == "timer_dynamic_enumerate")
  #expect(descriptor.types[0].callAsFunctionBinding == "timer_call")
}

@Test func genericHandlesKeepOpaqueStorageAndEngineTyping() {
  let runtime = JSRuntimeHandle<MockEngine>(_opaqueHandle: "runtime-token")
  let context = JSBorrowedContextHandle<MockEngine>(_opaqueHandle: 42)
  let value = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "value-token"))

  let runtimeToken = runtime.opaqueHandle(as: String.self)
  let contextToken = context.opaqueHandle(as: Int.self)
  let valueToken = value.rawValue
  let runtimeIsMock = runtime.engineType == MockEngine.self
  let contextIsMock = context.engineType == MockEngine.self
  let valueIsMock = value.engineType == MockEngine.self

  #expect(runtimeToken == "runtime-token")
  #expect(contextToken == 42)
  #expect(valueToken == MockValue(kind: "string", payload: "value-token"))
  #expect(runtimeIsMock)
  #expect(contextIsMock)
  #expect(valueIsMock)
}

@Test func engineValueStoragePreservesHandleAndEngineType() {
  let handle = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "mock-value"))
  let storage = JSEngineValueStorage<MockEngine>(handle: handle)

  let storedHandle = storage.valueHandle()

  #expect(storedHandle.rawValue == MockValue(kind: "string", payload: "mock-value"))
  #expect(storedHandle.engineType == MockEngine.self)
}

@Test func engineValueStorageKeepsOpaquePayloadIdentity() {
  let payload = MockValue(kind: "number", payload: "runtime:7")
  let handle = JSValueHandle<MockEngine>(rawValue: payload)
  let storage = JSEngineValueStorage<MockEngine>(handle: handle)

  let roundtrip = storage.valueHandle().rawValue

  #expect(roundtrip == payload)
}

@Test func engineValueShellKeepsStorageAndEngineTyping() {
  let handle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "moved-jsvalue"))
  let storage = JSEngineValueStorage<MockEngine>(handle: handle)
  let value = JSEngineValue<MockEngine>(storage: storage)

  let roundtripHandle = value._rawValue.valueHandle()
  #expect(roundtripHandle.rawValue == MockValue(kind: "string", payload: "moved-jsvalue"))
  #expect(roundtripHandle.engineType == MockEngine.self)
}

@Test func genericResultHandleWrapsValueAndExceptionStates() {
  let valueHandle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "mock-value")
  )
  let exceptionHandle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "exception", payload: "mock-error")
  )

  let valueResult = JSResultHandle<MockEngine>.value(valueHandle)
  let exceptionResult = JSResultHandle<MockEngine>.exception(exceptionHandle)

  let valueIsException = valueResult.isException
  let exceptionIsException = exceptionResult.isException

  #expect(!valueIsException)
  #expect(exceptionIsException)

  switch consume valueResult {
  case .value(let wrapped):
    #expect(wrapped.rawValue == MockValue(kind: "string", payload: "mock-value"))
  case .exception:
    Issue.record("Expected value result case")
  }

  switch consume exceptionResult {
  case .value:
    Issue.record("Expected exception result case")
  case .exception(let wrapped):
    #expect(wrapped.rawValue == MockValue(kind: "exception", payload: "mock-error"))
  }
}

@Test func genericHandlesBridgeThroughDriverProtocol() {
  let runtime = MockDriver.makeRuntimeHandle()
  let context = MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)

  guard let context else {
    Issue.record("Expected context handle from driver")
    return
  }

  let stringValue = MockDriver.makeStringValueHandle("hello", context)
  let symbolValue = MockDriver.makeSymbolValueHandle("token", context)
  let numberValue = MockDriver.makeNumberValueHandle(42, context)
  let evalValue = MockDriver.evaluateScriptResultHandle("1 + 2", context)
  let evalException = MockDriver.evaluateScriptResultHandle("throw", context)

  guard let stringValue, let symbolValue, let numberValue, let evalValue, let evalException else {
    Issue.record("Expected driver bridge operations to produce handles")
    return
  }

  let names = MockDriver.propertyNamesForHandle(on: stringValue, in: context)
  let property = MockDriver.getStringPropertyHandle("message", on: stringValue, in: context)
  let propertySet = MockDriver.setStringPropertyHandle(
    "message",
    on: stringValue,
    to: numberValue,
    in: context,
    attributes: [.readOnly]
  )

  #expect(propertySet)
  #expect(names == ["runtime", "string", "runtime:hello"])
  #expect(
    symbolValue.rawValue
      == MockValue(kind: "symbol", payload: "runtime:token"))

  switch consume evalValue {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "script", payload: "runtime:1 + 2"))
  case .exception:
    Issue.record("Expected script evaluation to succeed")
  }

  switch consume evalException {
  case .value:
    Issue.record("Expected script evaluation to surface exception result")
  case .exception(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "exception", payload: "runtime:throw"))
  }

  guard let property else {
    Issue.record("Expected property handle result")
    return
  }

  switch consume property {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "property", payload: "runtime:runtime:hello:message"))
  case .exception:
    Issue.record("Expected property access to succeed")
  }
}

@Test func genericHandlesBridgeObjectsCallsAndTypeHelpers() {
  let runtime = MockDriver.makeRuntimeHandle()
  let context = MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)

  guard let context else {
    Issue.record("Expected context handle from driver")
    return
  }

  let object = MockDriver.makeObjectResultHandle(context)
  let array = MockDriver.makeArrayResultHandle(context)
  let function = MockDriver.makeStringValueHandle("callable", context)
  let argument = MockDriver.makeNumberValueHandle(7, context)
  let primitive = MockDriver.makeStringValueHandle("boxed", context)
  let constructor = MockDriver.makeStringValueHandle("boxed", context)
  let nullValue = MockDriver.makeNullValueHandle(context)
  let undefinedValue = MockDriver.makeUndefinedValueHandle(context)

  guard let object, let array, let function, let argument, let primitive, let constructor,
    let nullValue, let undefinedValue
  else {
    Issue.record("Expected object/array/call scaffolding handles")
    return
  }

  let callResult = MockDriver.callFunctionHandle(function, arguments: [argument], in: context)
  let constructResult = MockDriver.constructHandle(function, arguments: [argument], in: context)
  let boxedResult = MockDriver.toObjectHandle(primitive, in: context)
  let isArray = MockDriver.isArrayHandle(function, in: context)
  let isDate = MockDriver.isDateHandle(function, in: context)
  let isInstanceOf = MockDriver.isInstanceOfHandle(primitive, constructor: constructor, in: context)

  switch consume object {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "object", payload: "runtime"))
  case .exception:
    Issue.record("Expected object creation to succeed")
  }

  switch consume array {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "array", payload: "runtime"))
  case .exception:
    Issue.record("Expected array creation to succeed")
  }

  switch consume callResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "call", payload: "runtime:runtime:callable:1"))
  default:
    Issue.record("Expected function call to succeed")
  }

  switch consume constructResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "construct", payload: "runtime:1"))
  default:
    Issue.record("Expected constructor call to succeed")
  }

  switch consume boxedResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "object", payload: "runtime:boxed"))
  default:
    Issue.record("Expected toObject bridge to succeed")
  }

  #expect(isArray == false)
  #expect(isDate == false)
  #expect(isInstanceOf == true)
  #expect(nullValue.rawValue == MockValue(kind: "null", payload: "runtime"))
  #expect(
    undefinedValue.rawValue
      == MockValue(kind: "undefined", payload: "runtime"))
}
