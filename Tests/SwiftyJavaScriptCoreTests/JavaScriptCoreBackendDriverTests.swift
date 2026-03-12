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
