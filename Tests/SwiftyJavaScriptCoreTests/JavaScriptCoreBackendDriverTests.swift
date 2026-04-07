import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

private func makeBackendString(
  _ value: String,
  in context: JavaScriptCoreContextHandle
) -> JSValueHandle<JavaScriptCoreEngine> {
  JavaScriptCoreEngine.makeStringValueHandle(value, context)!
}

private func evaluateBackendScript(
  _ script: String,
  in context: JavaScriptCoreContextHandle,
  sourceURL: String? = nil,
  startingLineNumber: Int32 = 1
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  JavaScriptCoreEngine.evaluateScriptResultHandle(
    script,
    context,
    sourceURL: sourceURL,
    startingLineNumber: startingLineNumber
  )!
}

private func makeBackendObject(
  in context: JavaScriptCoreContextHandle
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  JavaScriptCoreEngine.makeObjectResultHandle(context)!
}

private func makeBackendArray(
  in context: JavaScriptCoreContextHandle
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  JavaScriptCoreEngine.makeArrayResultHandle(context)!
}

@Test func javaScriptCoreBackendDriverSupportsPhaseOnePrimitivesAndProperties() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  #expect(JavaScriptCoreEngine.capabilities.supportsHostObjects)
  #expect(JavaScriptCoreEngine.capabilities.supportsSymbol)

  let number = JavaScriptCoreEngine.makeNumberValueHandle(42, context)!
  let string = makeBackendString("hello", in: context)

  #expect(JavaScriptCoreEngine.valueTypeForHandle(number, in: context) == .number)
  #expect(JavaScriptCoreEngine.toNumberForHandle(number, in: context) == 42)
  #expect(JavaScriptCoreEngine.valueTypeForHandle(string, in: context) == .string)
  #expect(JavaScriptCoreEngine.toStringForHandle(string, in: context) == "hello")

  switch evaluateBackendScript(
    "({})",
    in: context,
    sourceURL: "driver-test.js",
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let answer = JavaScriptCoreEngine.makeNumberValueHandle(99, context)!

    if !JavaScriptCoreEngine.setStringPropertyHandle(
      "answer",
      on: object,
      to: answer,
      in: context,
      attributes: [.readOnly]
    ) {
      Issue.record("expected property assignment to succeed")
    }

    switch JavaScriptCoreEngine.getStringPropertyHandle("answer", on: object, in: context) {
    case .none, .some(.exception):
      Issue.record("expected property read to succeed")
    case .some(.value(let property)):
      #expect(JavaScriptCoreEngine.valueTypeForHandle(property, in: context) == .number)
      #expect(JavaScriptCoreEngine.toNumberForHandle(property, in: context) == 99)
    }
  }
}

@Test func javaScriptCoreBackendDriverHandleReferenceCountingChain() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  #expect(runtimeHandle.retainReference())
  #expect(runtimeHandle.releaseReference())

  guard
    let contextHandle = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(
      in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  #expect(contextHandle.retainReference())
  #expect(contextHandle.releaseReference())

  // Release the creation-time references so this test does not leak engine objects.
  #expect(contextHandle.releaseReference())
  #expect(runtimeHandle.releaseReference())
}

@Test func javaScriptCoreBackendDriverReturnsExceptionsFromEvaluation() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  switch evaluateBackendScript(
    "throw new Error('boom')",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .value:
    Issue.record("expected thrown script to surface as exception")
  case .exception(let exception):
    #expect(JavaScriptCoreEngine.valueTypeForHandle(exception, in: context) == .object)
    #expect(JavaScriptCoreEngine.toStringForHandle(exception, in: context) == "Error: boom")
  }
}

@Test func javaScriptCoreBackendDriverSupportsObjectArrayAndCalls() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  switch makeBackendObject(in: context) {
  case .exception:
    Issue.record("expected object creation to succeed")
  case .value(let object):
    switch makeBackendArray(in: context) {
    case .exception:
      Issue.record("expected array creation to succeed")
    case .value(let array):
      #expect(JavaScriptCoreEngine.valueTypeForHandle(object, in: context) == .object)
      #expect(JavaScriptCoreEngine.valueTypeForHandle(array, in: context) == .object)
    }
  }

  switch evaluateBackendScript(
    "(function(a, b) { return this.base + a + b })",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected function evaluation to succeed")
  case .value(let function):
    switch makeBackendObject(in: context) {
    case .exception:
      Issue.record("expected receiver object creation to succeed")
    case .value(let thisObject):
      let base = JavaScriptCoreEngine.makeNumberValueHandle(10, context)!
      _ = JavaScriptCoreEngine.setStringPropertyHandle(
        "base",
        on: thisObject,
        to: base,
        in: context,
        attributes: .none
      )
      let one = JavaScriptCoreEngine.makeNumberValueHandle(1, context)!
      let two = JavaScriptCoreEngine.makeNumberValueHandle(2, context)!

      switch JavaScriptCoreEngine.callFunctionHandle(
        function,
        this: thisObject,
        arguments: [one, two],
        in: context
      ) {
      case .none, .some(.exception):
        Issue.record("expected backend function call to succeed")
      case .some(.value(let result)):
        #expect(JavaScriptCoreEngine.valueTypeForHandle(result, in: context) == .number)
        #expect(JavaScriptCoreEngine.toNumberForHandle(result, in: context) == 13)
      }
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsHasAndDeleteProperty() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  switch evaluateBackendScript(
    "({})",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let value = makeBackendString("ok", in: context)
    _ = JavaScriptCoreEngine.setStringPropertyHandle(
      "status",
      on: object,
      to: value,
      in: context,
      attributes: .none
    )

    #expect(JavaScriptCoreEngine.hasStringPropertyHandle("status", on: object, in: context) == true)

    if !JavaScriptCoreEngine.deleteStringPropertyHandle("status", on: object, in: context) {
      Issue.record("expected property deletion to succeed")
    } else {
      #expect(
        JavaScriptCoreEngine.hasStringPropertyHandle("status", on: object, in: context) == false)
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsObjectTypeHelpers() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  switch evaluateBackendScript(
    "[1, 2, 3]", in: context, sourceURL: nil, startingLineNumber: 1)
  {
  case .exception:
    Issue.record("expected array evaluation to succeed")
  case .value(let array):
    switch evaluateBackendScript(
      "new Date(0)", in: context, sourceURL: nil, startingLineNumber: 1)
    {
    case .exception:
      Issue.record("expected date evaluation to succeed")
    case .value(let date):
      switch evaluateBackendScript(
        "Array", in: context, sourceURL: nil, startingLineNumber: 1)
      {
      case .exception:
        Issue.record("expected Array constructor evaluation to succeed")
      case .value(let arrayConstructor):
        let arrayHandle = array
        let dateHandle = date
        #expect(JavaScriptCoreEngine.isArrayHandle(arrayHandle, in: context) == true)
        #expect(JavaScriptCoreEngine.isDateHandle(arrayHandle, in: context) == false)
        #expect(JavaScriptCoreEngine.isDateHandle(dateHandle, in: context) == true)
        #expect(
          JavaScriptCoreEngine.isInstanceOfHandle(
            array, constructor: arrayConstructor, in: context) == true)

        let primitive = JavaScriptCoreEngine.makeNumberValueHandle(42, context)!
        switch JavaScriptCoreEngine.toObjectHandle(primitive, in: context) {
        case .none, .some(.exception):
          Issue.record("expected toObject to box primitive numbers")
        case .some(.value(let object)):
          #expect(JavaScriptCoreEngine.valueTypeForHandle(object, in: context) == .object)
        }
      }
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsValueKeyAndIndexedProperties() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  switch makeBackendObject(in: context) {
  case .exception:
    Issue.record("expected object creation to succeed")
  case .value(let object):
    let key = makeBackendString("driverKey", in: context)
    let value = makeBackendString("driverValue", in: context)

    if !JavaScriptCoreEngine.setValuePropertyHandle(
      key,
      on: object,
      to: value,
      in: context,
      attributes: .none
    ) {
      Issue.record("expected value-key property set to succeed")
    } else {
      #expect(JavaScriptCoreEngine.hasValuePropertyHandle(key, on: object, in: context) == true)
      switch JavaScriptCoreEngine.getValuePropertyHandle(key, on: object, in: context) {
      case .none, .some(.exception):
        Issue.record("expected value-key property get to succeed")
      case .some(.value(let stored)):
        #expect(JavaScriptCoreEngine.toStringForHandle(stored, in: context) == "driverValue")
      }
    }

    let indexedValue = JavaScriptCoreEngine.makeBooleanValueHandle(true, context)!
    if !JavaScriptCoreEngine.setIndexPropertyHandle(
      at: 2,
      on: object,
      to: indexedValue,
      in: context
    ) {
      Issue.record("expected indexed property set to succeed")
    } else {
      switch JavaScriptCoreEngine.getIndexPropertyHandle(at: 2, on: object, in: context) {
      case .none, .some(.exception):
        Issue.record("expected indexed property get to succeed")
      case .some(.value(let stored)):
        #expect(JavaScriptCoreEngine.valueTypeForHandle(stored, in: context) == .boolean)
      }
    }

    if !JavaScriptCoreEngine.deleteValuePropertyHandle(key, on: object, in: context) {
      Issue.record("expected value-key property delete to succeed")
    } else {
      #expect(JavaScriptCoreEngine.hasValuePropertyHandle(key, on: object, in: context) == false)
    }
  }
}

@Test func javaScriptCoreBackendDriverEnumeratesPropertyNames() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  guard let context = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  switch evaluateBackendScript(
    "({ alpha: 1, beta: 2 })",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let names = Set(JavaScriptCoreEngine.propertyNamesForHandle(on: object, in: context) ?? [])
    #expect(names.contains("alpha"))
    #expect(names.contains("beta"))
  }
}

@Test func javaScriptCoreBackendDriverConsumesJSClassHostDescriptorBindings() {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()
  definition.className = "BackendProjected"
  definition.staticValues = [
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>(
      name: "version",
      attributes: .readOnly,
      getProperty: { context, _ in
        .value(JSValue(number: 1, in: context))
      },
      setProperty: { context, _, _ in
        .value(JSValue(undefinedIn: context))
      }
    )
  ]
  definition.staticFunctions = [
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in
        .value(JSValue(string: "pong", in: context))
      }
    )
  ]
  definition.getProperty = { context, _, _ in
    .value(JSValue(undefinedIn: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.hasProperty = { _, _, _ in true }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSValue(objectIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }

  let descriptor = definition.hostTypeDescriptor()

  #expect(descriptor.name == "BackendProjected")
  #expect(!descriptor.properties.isEmpty)
  #expect(!descriptor.methods.isEmpty)
  #expect(descriptor.dynamicPropertyGetterBinding != nil)
  #expect(descriptor.dynamicPropertySetterBinding != nil)
  #expect(descriptor.dynamicPropertyHasBinding != nil)
  #expect(descriptor.dynamicPropertyDeleteBinding != nil)
  #expect(descriptor.propertyEnumeratorBinding != nil)
  #expect(descriptor.callAsFunctionBinding != nil)
  #expect(descriptor.constructor?.binding != nil)
  #expect(descriptor.hasInstanceBinding != nil)
  #expect(descriptor.convertToTypeBinding != nil)
}
