import Testing

@testable import SwiftJavaScript

private enum MockEngine: JSEngine {}

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

private enum MockDriver: _JSEngineDriver {
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
  let runtime = JSRuntimeHandle<JavaScriptCoreEngine>(_opaqueHandle: "runtime-token")
  let context = JSBorrowedContextHandle<JavaScriptCoreEngine>(_opaqueHandle: 42)
  let value = JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: "value-token")

  let runtimeToken = runtime.opaqueHandle(as: String.self)
  let contextToken = context.opaqueHandle(as: Int.self)
  let valueToken = value.opaqueHandle(as: String.self)
  let runtimeIsJSC = runtime.engineType == JavaScriptCoreEngine.self
  let contextIsJSC = context.engineType == JavaScriptCoreEngine.self
  let valueIsJSC = value.engineType == JavaScriptCoreEngine.self

  #expect(runtimeToken == "runtime-token")
  #expect(contextToken == 42)
  #expect(valueToken == "value-token")
  #expect(runtimeIsJSC)
  #expect(contextIsJSC)
  #expect(valueIsJSC)
}

@Test func genericResultHandleWrapsValueAndExceptionStates() {
  let valueHandle = JSValueHandle<QuickJSEngine>(_opaqueHandle: "quickjs-value")
  let exceptionHandle = JSValueHandle<QuickJSEngine>(_opaqueHandle: "quickjs-error")

  let valueResult = JSResultHandle<QuickJSEngine>.value(valueHandle)
  let exceptionResult = JSResultHandle<QuickJSEngine>.exception(exceptionHandle)

  let valueIsException = valueResult.isException
  let exceptionIsException = exceptionResult.isException

  #expect(!valueIsException)
  #expect(exceptionIsException)

  switch consume valueResult {
  case .value(let wrapped):
    let token = wrapped.opaqueHandle(as: String.self)
    #expect(token == "quickjs-value")
  case .exception:
    Issue.record("Expected value result case")
  }

  switch consume exceptionResult {
  case .value:
    Issue.record("Expected exception result case")
  case .exception(let wrapped):
    let token = wrapped.opaqueHandle(as: String.self)
    #expect(token == "quickjs-error")
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
  let numberValue = MockDriver.makeNumberValueHandle(42, context)
  let evalValue = MockDriver.evaluateScriptResultHandle("1 + 2", context)
  let evalException = MockDriver.evaluateScriptResultHandle("throw", context)

  guard let stringValue, let numberValue, let evalValue, let evalException else {
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

  switch consume evalValue {
  case .value(let value):
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "script", payload: "runtime:1 + 2"))
  case .exception:
    Issue.record("Expected script evaluation to succeed")
  }

  switch consume evalException {
  case .value:
    Issue.record("Expected script evaluation to surface exception result")
  case .exception(let value):
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "exception", payload: "runtime:throw"))
  }

  guard let property else {
    Issue.record("Expected property handle result")
    return
  }

  switch consume property {
  case .value(let value):
    let raw = value.opaqueHandle(as: MockValue.self)
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
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "object", payload: "runtime"))
  case .exception:
    Issue.record("Expected object creation to succeed")
  }

  switch consume array {
  case .value(let value):
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "array", payload: "runtime"))
  case .exception:
    Issue.record("Expected array creation to succeed")
  }

  switch consume callResult {
  case .some(.value(let value)):
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "call", payload: "runtime:runtime:callable:1"))
  default:
    Issue.record("Expected function call to succeed")
  }

  switch consume constructResult {
  case .some(.value(let value)):
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "construct", payload: "runtime:1"))
  default:
    Issue.record("Expected constructor call to succeed")
  }

  switch consume boxedResult {
  case .some(.value(let value)):
    let raw = value.opaqueHandle(as: MockValue.self)
    #expect(raw == MockValue(kind: "object", payload: "runtime:boxed"))
  default:
    Issue.record("Expected toObject bridge to succeed")
  }

  #expect(isArray == false)
  #expect(isDate == false)
  #expect(isInstanceOf == true)
  #expect(nullValue.opaqueHandle(as: MockValue.self) == MockValue(kind: "null", payload: "runtime"))
  #expect(
    undefinedValue.opaqueHandle(as: MockValue.self)
      == MockValue(kind: "undefined", payload: "runtime"))
}
