import Testing

@testable import SwiftyJavaScriptCore

@Test func evaluateScriptReturnsValueForValidScript() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let result = context.evaluateScript("1 + 2")

    switch consume result {
    case .value(let value):
      let expected = JSValue(number: 3, in: context)
      let isStrictlyEqual = value === expected
      #expect(isStrictlyEqual)
    case .exception:
      Issue.record("Expected script to evaluate successfully")
    }
  }
}

@Test func evaluateScriptSupportsSourceURL() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let script = JSStringManaged("40 + 2")
    let sourceURL = JSStringManaged("inline://unit-test.js")
    let result = context.evaluateScript(script, sourceURL: sourceURL, startingLineNumber: 12)

    switch consume result {
    case .value(let value):
      let expected = JSValue(number: 42, in: context)
      let isStrictlyEqual = value === expected
      #expect(isStrictlyEqual)
    case .exception:
      Issue.record("Expected script with sourceURL to evaluate successfully")
    }
  }
}

@Test func evaluateScriptReturnsExceptionForThrowingScript() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let result = context.evaluateScript("throw new Error('boom')", sourceURL: "inline://throw.js")

    switch consume result {
    case .value:
      Issue.record("Expected JavaScript exception")
    case .exception(let exception):
      let isObject = exception.isObject
      #expect(isObject)
    }
  }
}
