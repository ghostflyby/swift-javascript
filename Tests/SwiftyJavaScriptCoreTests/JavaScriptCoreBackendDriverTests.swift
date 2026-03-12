import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreBackendDriverSupportsPhaseOnePrimitivesAndProperties() {
  let runtime = JavaScriptCoreBackendDriver.makeRuntime()
  let context = JavaScriptCoreBackendDriver.makeContext(in: runtime)

  #expect(JavaScriptCoreBackendDriver.capabilities.supportsHostObjects)
  #expect(JavaScriptCoreBackendDriver.capabilities.supportsSymbol)

  let number = JavaScriptCoreBackendDriver.makeNumber(42, in: context)
  let string = JavaScriptCoreBackendDriver.makeString("hello", in: context)

  #expect(number.type == .number)
  #expect(number.toDouble() == 42)
  #expect(string.type == .string)
  #expect(string.toString() == "hello")

  switch JavaScriptCoreBackendDriver.evaluateScript(
    "({})",
    in: context,
    sourceURL: "driver-test.js",
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let answer = JavaScriptCoreBackendDriver.makeNumber(99, in: context)

    switch JavaScriptCoreBackendDriver.setProperty(
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

    switch JavaScriptCoreBackendDriver.getProperty("answer", on: object, in: context) {
    case .exception:
      Issue.record("expected property read to succeed")
    case .value(let property):
      #expect(property.type == .number)
      #expect(property.toDouble() == 99)
    }
  }
}

@Test func javaScriptCoreBackendDriverReturnsExceptionsFromEvaluation() {
  let runtime = JavaScriptCoreBackendDriver.makeRuntime()
  let context = JavaScriptCoreBackendDriver.makeContext(in: runtime)

  switch JavaScriptCoreBackendDriver.evaluateScript(
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
  let runtime = JavaScriptCoreBackendDriver.makeRuntime()
  let context = JavaScriptCoreBackendDriver.makeContext(in: runtime)

  switch JavaScriptCoreBackendDriver.makeObject(in: context) {
  case .exception:
    Issue.record("expected object creation to succeed")
  case .value(let object):
    switch JavaScriptCoreBackendDriver.makeArray(in: context) {
    case .exception:
      Issue.record("expected array creation to succeed")
    case .value(let array):
      #expect(object.type == .object)
      #expect(array.type == .object)
    }
  }

  switch JavaScriptCoreBackendDriver.evaluateScript(
    "(function(a, b) { return this.base + a + b })",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected function evaluation to succeed")
  case .value(let function):
    switch JavaScriptCoreBackendDriver.makeObject(in: context) {
    case .exception:
      Issue.record("expected receiver object creation to succeed")
    case .value(let thisObject):
      let base = JavaScriptCoreBackendDriver.makeNumber(10, in: context)
      _ = JavaScriptCoreBackendDriver.setProperty(
        "base",
        on: thisObject,
        to: base,
        in: context,
        attributes: .none
      )
      let one = JavaScriptCoreBackendDriver.makeNumber(1, in: context)
      let two = JavaScriptCoreBackendDriver.makeNumber(2, in: context)

      switch JavaScriptCoreBackendDriver.callFunction(
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
  let runtime = JavaScriptCoreBackendDriver.makeRuntime()
  let context = JavaScriptCoreBackendDriver.makeContext(in: runtime)

  switch JavaScriptCoreBackendDriver.evaluateScript(
    "({})",
    in: context,
    sourceURL: nil,
    startingLineNumber: 1
  ) {
  case .exception:
    Issue.record("expected object literal evaluation to succeed")
  case .value(let object):
    let value = JavaScriptCoreBackendDriver.makeString("ok", in: context)
    _ = JavaScriptCoreBackendDriver.setProperty(
      "status",
      on: object,
      to: value,
      in: context,
      attributes: .none
    )

    #expect(JavaScriptCoreBackendDriver.hasProperty("status", on: object, in: context))

    switch JavaScriptCoreBackendDriver.deleteProperty("status", on: object, in: context) {
    case .exception:
      Issue.record("expected property deletion to succeed")
    case .value:
      #expect(!JavaScriptCoreBackendDriver.hasProperty("status", on: object, in: context))
    }
  }
}

@Test func javaScriptCoreBackendDriverSupportsObjectTypeHelpers() {
  let runtime = JavaScriptCoreBackendDriver.makeRuntime()
  let context = JavaScriptCoreBackendDriver.makeContext(in: runtime)

  switch JavaScriptCoreBackendDriver.evaluateScript(
    "[1, 2, 3]", in: context, sourceURL: nil, startingLineNumber: 1)
  {
  case .exception:
    Issue.record("expected array evaluation to succeed")
  case .value(let array):
    switch JavaScriptCoreBackendDriver.evaluateScript(
      "new Date(0)", in: context, sourceURL: nil, startingLineNumber: 1)
    {
    case .exception:
      Issue.record("expected date evaluation to succeed")
    case .value(let date):
      switch JavaScriptCoreBackendDriver.evaluateScript(
        "Array", in: context, sourceURL: nil, startingLineNumber: 1)
      {
      case .exception:
        Issue.record("expected Array constructor evaluation to succeed")
      case .value(let arrayConstructor):
        #expect(JavaScriptCoreBackendDriver.isArray(array, in: context))
        #expect(!JavaScriptCoreBackendDriver.isDate(array, in: context))
        #expect(JavaScriptCoreBackendDriver.isDate(date, in: context))
        #expect(
          JavaScriptCoreBackendDriver.isInstanceOf(
            array, constructor: arrayConstructor, in: context))

        let primitive = JavaScriptCoreBackendDriver.makeNumber(42, in: context)
        switch JavaScriptCoreBackendDriver.toObject(primitive, in: context) {
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
  let runtime = JavaScriptCoreBackendDriver.makeRuntime()
  let context = JavaScriptCoreBackendDriver.makeContext(in: runtime)

  switch JavaScriptCoreBackendDriver.makeObject(in: context) {
  case .exception:
    Issue.record("expected object creation to succeed")
  case .value(let object):
    let key = JavaScriptCoreBackendDriver.makeString("driverKey", in: context)
    let value = JavaScriptCoreBackendDriver.makeString("driverValue", in: context)

    switch JavaScriptCoreBackendDriver.setProperty(
      key,
      on: object,
      to: value,
      in: context,
      attributes: .none
    ) {
    case .exception:
      Issue.record("expected value-key property set to succeed")
    case .value:
      #expect(JavaScriptCoreBackendDriver.hasProperty(key, on: object, in: context))
      switch JavaScriptCoreBackendDriver.getProperty(key, on: object, in: context) {
      case .exception:
        Issue.record("expected value-key property get to succeed")
      case .value(let stored):
        #expect(stored.toString() == "driverValue")
      }
    }

    let indexedValue = JavaScriptCoreBackendDriver.makeBoolean(true, in: context)
    switch JavaScriptCoreBackendDriver.setProperty(at: 2, on: object, to: indexedValue, in: context)
    {
    case .exception:
      Issue.record("expected indexed property set to succeed")
    case .value:
      switch JavaScriptCoreBackendDriver.getProperty(at: 2, on: object, in: context) {
      case .exception:
        Issue.record("expected indexed property get to succeed")
      case .value(let stored):
        #expect(stored.type == .boolean)
      }
    }

    switch JavaScriptCoreBackendDriver.deleteProperty(key, on: object, in: context) {
    case .exception:
      Issue.record("expected value-key property delete to succeed")
    case .value:
      #expect(!JavaScriptCoreBackendDriver.hasProperty(key, on: object, in: context))
    }
  }
}
