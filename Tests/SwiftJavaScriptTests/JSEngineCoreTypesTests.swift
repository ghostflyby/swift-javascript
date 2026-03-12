import Testing

@testable import SwiftJavaScript

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
