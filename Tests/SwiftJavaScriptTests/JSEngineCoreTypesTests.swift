import Foundation
import SwiftJavaScriptTestSupport
import Testing

@testable import SwiftJavaScript

@Test func jsValueHandleStorageWordsRoundTripMockHandlePointerWord() {
  let handle = MockValueHandle(rawValue: MockValue(kind: "number", payload: "42"))
  defer { _ = handle.releaseReference() }

  let storageWords = handle.storageWords

  #expect(storageWords.word1 == 0)
  #expect(storageWords.word2 == 0)

  let restored = MockValueHandle(storageWords: storageWords)
  #expect(restored.rawValue == handle.rawValue)
}

@Test func jsValueHandleStorageWordsKeepThreeWordLayout() {
  #expect(MemoryLayout<JSValueStorageWords>.size == 3 * MemoryLayout<UInt64>.size)
  #expect(MemoryLayout<JSValueStorageWords>.stride == 3 * MemoryLayout<UInt64>.stride)
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

@Test func genericHandlesKeepRawStorageAndEngineTyping() {
  let runtime = MockRuntimeHandle(rawRuntime: MockRuntime(id: "runtime-token"))
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "runtime-token"))
  let value = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "value-token"))

  let runtimeToken = runtime.rawRuntime
  let contextToken = context.rawContext
  let valueToken = value.rawValue
  let runtimeIsMock = runtime.engineType == MockEngine.self
  let contextIsMock = context.engineType == MockEngine.self
  let valueIsMock = value.engineType == MockEngine.self

  #expect(runtimeToken == MockRuntime(id: "runtime-token"))
  #expect(contextToken == MockContext(runtimeID: "runtime-token"))
  #expect(valueToken == MockValue(kind: "string", payload: "value-token"))
  #expect(runtimeIsMock)
  #expect(contextIsMock)
  #expect(valueIsMock)
}

@Test func engineValuePreservesHandleAndEngineType() {
  let handle = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "mock-value"))
  let value = JSValue<MockEngine>(handleValue: handle)

  let storedHandle = value.borrowHandle()

  #expect(storedHandle.rawValue == MockValue(kind: "string", payload: "mock-value"))
  #expect(storedHandle.engineType == MockEngine.self)
}

@Test func engineValueKeepsOpaquePayloadIdentity() {
  let payload = MockValue(kind: "number", payload: "runtime:7")
  let handle = JSValueHandle<MockEngine>(rawValue: payload)
  let value = JSValue<MockEngine>(handleValue: handle)

  let roundtrip = value.borrowHandle().rawValue

  #expect(roundtrip == payload)
}

@Test func engineValueShellKeepsHandleAndEngineTyping() {
  let handle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "moved-jsvalue"))
  let value = JSValue<MockEngine>(handleValue: handle)

  let roundtripHandle = value.borrowHandle()
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

  let valueResult = JSResult<JSValueHandle<MockEngine>>.value(valueHandle)
  let exceptionResult = JSResult<JSValueHandle<MockEngine>>.exception(exceptionHandle)

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
  let property = MockDriver.getStringPropertyHandle(
    "message", on: stringValue, in: context)
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

  let callResult = MockDriver.callFunctionHandle(
    function, arguments: [argument], in: context)
  let constructResult = MockDriver.constructHandle(
    function, arguments: [argument], in: context)
  let boxedResult = MockDriver.toObjectHandle(primitive, in: context)
  let isArray = MockDriver.isArrayHandle(function, in: context)
  let isDate = MockDriver.isDateHandle(function, in: context)
  let isInstanceOf = MockDriver.isInstanceOfHandle(
    primitive, constructor: constructor, in: context)

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

@Test func genericValueEqualityUsesDriverHooks() async {
  let context = JSContext<MockEngine>()

  await context.withInstantContext { context in
    let oneNumber = JSValue<MockEngine>(number: 1, in: context)
    let oneString = JSValue<MockEngine>(string: "1.0", in: context)
    let oneNumberCopy = JSValue<MockEngine>(number: 1, in: context)
    let twoNumber = JSValue<MockEngine>(number: 2, in: context)

    let looselyEqual = oneNumber.looselyEquals(oneString, in: context)
    let looselyNotEqual = !oneNumber.looselyEquals(twoNumber, in: context)
    let strictlyEqual = oneNumber.strictlyEquals(oneNumberCopy, in: context)
    let strictlyNotEqual = !oneNumber.strictlyEquals(oneString, in: context)

    #expect(looselyEqual)
    #expect(looselyNotEqual)
    #expect(strictlyEqual)
    #expect(strictlyNotEqual)
  }
}
