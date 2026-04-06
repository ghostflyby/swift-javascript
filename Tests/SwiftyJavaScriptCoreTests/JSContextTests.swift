import Testing

@testable import SwiftyJavaScriptCore

@Test func evaluateScriptReturnsValueForValidScript() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let result = context.evaluateScript("1 + 2")

    switch consume result {
    case .value(let value):
      let expected = JSValue(number: 3, in: context)
      let isStrictlyEqual = value.strictlyEquals(expected, in: context)
      #expect(isStrictlyEqual)
    case .exception:
      Issue.record("Expected script to evaluate successfully")
    }
  }
}

@Test func evaluateScriptSupportsSourceURL() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let script = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("40 + 2")
    let sourceURL = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("inline://unit-test.js")
    let result = context.evaluateScript(script, sourceURL: sourceURL, startingLineNumber: 12)

    switch consume result {
    case .value(let value):
      let expected = JSValue(number: 42, in: context)
      let isStrictlyEqual = value.strictlyEquals(expected, in: context)
      #expect(isStrictlyEqual)
    case .exception:
      Issue.record("Expected script with sourceURL to evaluate successfully")
    }
  }
}

@Test func evaluateScriptReturnsExceptionForThrowingScript() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let result = context.evaluateScript("throw new Error('boom')", sourceURL: "inline://throw.js")

    switch consume result {
    case .value:
      Issue.record("Expected JavaScript exception")
    case .exception(let exception):
      let isObject = exception.isObject(in: context)
      #expect(isObject)
    }
  }
}

@Test func instantContextSupportsNativeModuleStyleGlobalHelpers() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withInstantContext { context in
    let answerKey = "answer"
    context.setGlobalProperty(41, forKey: answerKey)
    let hasAnswer = context.hasGlobalProperty(answerKey)
    #expect(hasAnswer)

    let answer = context.getGlobalProperty(forKey: answerKey)
    #expect(answer.toDouble(in: context) == 41)

    let object = context.makeObject()
    object.setProperty(
      context.makeBoolean(true),
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("flag"), in: context)
    let flagValue = object.getProperty(
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("flag"), in: context)
    let flag = flagValue.toBool(in: context)
    #expect(flag)

    context.installGlobalFunction(named: "bump") { context, _, _, arguments in
      let value = arguments.unpack(at: 0, using: JSDefaultConverter<Double>.self, in: context)
      return .value(context.makeNumber(value + 1))
    }

    let result = context.evaluateScript("bump(answer)")
    switch consume result {
    case .value(let value):
      #expect(value.toDouble(in: context) == 42)
    case .exception:
      Issue.record("Expected JSInstantContext-installed global function to be callable")
    }

    context.deleteGlobalProperty(forKey: answerKey)
    let hasAnswerAfterDelete = context.hasGlobalProperty(answerKey)
    #expect(!hasAnswerAfterDelete)
  }
}

@Test func contextThinWrapsInstantContextGlobalHelpers() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let countKey = "count"
    context.setGlobalProperty(5, forKey: countKey)
    let hasCount = context.hasGlobalProperty(countKey)
    #expect(hasCount)

    context.installGlobalFunction(named: "double") { context, _, _, arguments in
      let value = arguments.unpack(at: 0, using: JSDefaultConverter<Double>.self, in: context)
      return .value(context.makeNumber(value * 2))
    }

    let result = context.evaluateScript("double(count)")
    switch consume result {
    case .value(let value):
      let doubled = value.toDouble(in: context)
      #expect(doubled == 10)
    case .exception:
      Issue.record("Expected JSContext thin wrappers to install callable globals")
    }

    let count = context.getGlobalProperty(forKey: countKey)
    let countValue = count.toDouble(in: context)
    #expect(countValue == 5)

    context.deleteGlobalProperty(forKey: countKey)
    let hasCountAfterDelete = context.hasGlobalProperty(countKey)
    #expect(!hasCountAfterDelete)
  }
}
