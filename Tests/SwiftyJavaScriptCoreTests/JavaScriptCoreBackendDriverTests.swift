import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreBackendDriverSupportsPhaseOnePrimitivesAndProperties() {
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  #expect(JavaScriptCoreEngine.capabilities.supportsHostObjects)
  #expect(JavaScriptCoreEngine.capabilities.supportsSymbol)

  let number = JavaScriptCoreEngine.makeNumber(42, in: context)
  let string = JavaScriptCoreEngine.makeString("hello", in: context)

  #expect(number.type == .number)
  #expect(number.toDouble() == 42)
  #expect(string.type == .string)
  #expect(string.toString() == "hello")

  switch JavaScriptCoreEngine.evaluateScript(
    "({})",
    in: context,
    sourceURL: "driver-test.js",
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let answer = JavaScriptCoreEngine.makeNumber(99, in: context)

    switch JavaScriptCoreEngine.setProperty(
      "answer",
      on: object,
      to: answer,
      in: context,
      attributes: [.readOnly]
    ) {
    case .exception:
      Issue.record("expected property assignment to succeed")
    case .value:
      break
    }

    switch JavaScriptCoreEngine.getProperty("answer", on: object, in: context) {
    case .exception:
      Issue.record("expected property read to succeed")
    case .value(let property):
      #expect(property.type == .number)
      #expect(property.toDouble() == 99)
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
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  switch JavaScriptCoreEngine.evaluateScript(
    "throw new Error('boom')",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .value:
    Issue.record("expected thrown script to surface as exception")
  case .exception(let exception):
    #expect(exception.type == .object)
    #expect(exception.toString() == "Error: boom")
  }
}

@Test func javaScriptCoreBackendDriverSupportsObjectArrayAndCalls() {
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  switch JavaScriptCoreEngine.makeObject(in: context) {
  case .exception:
    Issue.record("expected object creation to succeed")
  case .value(let object):
    switch JavaScriptCoreEngine.makeArray(in: context) {
    case .exception:
      Issue.record("expected array creation to succeed")
    case .value(let array):
      #expect(object.type == .object)
      #expect(array.type == .object)
    }
  }

  switch JavaScriptCoreEngine.evaluateScript(
    "(function(a, b) { return this.base + a + b })",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected function evaluation to succeed")
  case .value(let function):
    switch JavaScriptCoreEngine.makeObject(in: context) {
    case .exception:
      Issue.record("expected receiver object creation to succeed")
    case .value(let thisObject):
      let base = JavaScriptCoreEngine.makeNumber(10, in: context)
      _ = JavaScriptCoreEngine.setProperty(
        "base",
        on: thisObject,
        to: base,
        in: context,
        attributes: .none
      )
      let one = JavaScriptCoreEngine.makeNumber(1, in: context)
      let two = JavaScriptCoreEngine.makeNumber(2, in: context)

      switch JavaScriptCoreEngine.callFunction(
        function,
        this: thisObject,
        arguments: [one, two],
        in: context
      ) {
      case .exception:
        Issue.record("expected backend function call to succeed")
      case .value(let result):
        #expect(result.type == .number)
        #expect(result.toDouble() == 13)
      }
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsHasAndDeleteProperty() {
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  switch JavaScriptCoreEngine.evaluateScript(
    "({})",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let value = JavaScriptCoreEngine.makeString("ok", in: context)
    _ = JavaScriptCoreEngine.setProperty(
      "status",
      on: object,
      to: value,
      in: context,
      attributes: .none
    )

    #expect(JavaScriptCoreEngine.hasProperty("status", on: object, in: context))

    switch JavaScriptCoreEngine.deleteProperty("status", on: object, in: context) {
    case .exception:
      Issue.record("expected property deletion to succeed")
    case .value:
      #expect(!JavaScriptCoreEngine.hasProperty("status", on: object, in: context))
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsObjectTypeHelpers() {
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  switch JavaScriptCoreEngine.evaluateScript(
    "[1, 2, 3]", in: context, sourceURL: nil, startingLineNumber: 1)
  {
  case .exception:
    Issue.record("expected array evaluation to succeed")
  case .value(let array):
    switch JavaScriptCoreEngine.evaluateScript(
      "new Date(0)", in: context, sourceURL: nil, startingLineNumber: 1)
    {
    case .exception:
      Issue.record("expected date evaluation to succeed")
    case .value(let date):
      switch JavaScriptCoreEngine.evaluateScript(
        "Array", in: context, sourceURL: nil, startingLineNumber: 1)
      {
      case .exception:
        Issue.record("expected Array constructor evaluation to succeed")
      case .value(let arrayConstructor):
        #expect(JavaScriptCoreEngine.isArray(array, in: context))
        #expect(!JavaScriptCoreEngine.isDate(array, in: context))
        #expect(JavaScriptCoreEngine.isDate(date, in: context))
        #expect(
          JavaScriptCoreEngine.isInstanceOf(
            array, constructor: arrayConstructor, in: context))

        let primitive = JavaScriptCoreEngine.makeNumber(42, in: context)
        switch JavaScriptCoreEngine.toObject(primitive, in: context) {
        case .exception:
          Issue.record("expected toObject to box primitive numbers")
        case .value(let object):
          #expect(object.type == .object)
        }
      }
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsValueKeyAndIndexedProperties() {
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  switch JavaScriptCoreEngine.makeObject(in: context) {
  case .exception:
    Issue.record("expected object creation to succeed")
  case .value(let object):
    let key = JavaScriptCoreEngine.makeString("driverKey", in: context)
    let value = JavaScriptCoreEngine.makeString("driverValue", in: context)

    switch JavaScriptCoreEngine.setProperty(
      key,
      on: object,
      to: value,
      in: context,
      attributes: .none
    ) {
    case .exception:
      Issue.record("expected value-key property set to succeed")
    case .value:
      #expect(JavaScriptCoreEngine.hasProperty(key, on: object, in: context))
      switch JavaScriptCoreEngine.getProperty(key, on: object, in: context) {
      case .exception:
        Issue.record("expected value-key property get to succeed")
      case .value(let stored):
        #expect(stored.toString() == "driverValue")
      }
    }

    let indexedValue = JavaScriptCoreEngine.makeBoolean(true, in: context)
    switch JavaScriptCoreEngine.setProperty(at: 2, on: object, to: indexedValue, in: context)
    {
    case .exception:
      Issue.record("expected indexed property set to succeed")
    case .value:
      switch JavaScriptCoreEngine.getProperty(at: 2, on: object, in: context) {
      case .exception:
        Issue.record("expected indexed property get to succeed")
      case .value(let stored):
        #expect(stored.type == .boolean)
      }
    }

    switch JavaScriptCoreEngine.deleteProperty(key, on: object, in: context) {
    case .exception:
      Issue.record("expected value-key property delete to succeed")
    case .value:
      #expect(!JavaScriptCoreEngine.hasProperty(key, on: object, in: context))
    }
  }
}

@Test func javaScriptCoreBackendDriverEnumeratesPropertyNames() {
  let runtime = JavaScriptCoreEngine.makeRuntime()
  let context = JavaScriptCoreEngine.makeContext(in: runtime)

  switch JavaScriptCoreEngine.evaluateScript(
    "({ alpha: 1, beta: 2 })",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let names = Set(JavaScriptCoreEngine.propertyNames(on: object, in: context))
    #expect(names.contains("alpha"))
    #expect(names.contains("beta"))
  }
}

@Test func javaScriptCoreBackendDriverConsumesJSClassHostDescriptorBindings() {
  var definition = SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JavaScriptCorePropertyNameAccumulatorRef
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

  let descriptor = JavaScriptCoreEngine.hostTypeDescriptor(for: definition)

  #expect(descriptor.name == "BackendProjected")
  #expect(!descriptor.properties.isEmpty)
  #expect(!descriptor.methods.isEmpty)
  #expect(JavaScriptCoreEngine.hasDynamicPropertyGetter(for: descriptor))
  #expect(JavaScriptCoreEngine.hasDynamicPropertySetter(for: descriptor))
  #expect(JavaScriptCoreEngine.hasDynamicPropertyHas(for: descriptor))
  #expect(JavaScriptCoreEngine.hasDynamicPropertyDelete(for: descriptor))
  #expect(JavaScriptCoreEngine.hasPropertyEnumerator(for: descriptor))
  #expect(JavaScriptCoreEngine.hasCallAsFunction(for: descriptor))
  #expect(JavaScriptCoreEngine.hasConstructor(for: descriptor))
  #expect(JavaScriptCoreEngine.hasHasInstance(for: descriptor))
  #expect(JavaScriptCoreEngine.hasConvertToType(for: descriptor))
}
