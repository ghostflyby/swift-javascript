import Testing

@testable import SwiftyQuickJS

@Test func quickJSEvaluateScriptReturnsValue() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withInstantContext { context in
    let result = context.evaluateScript("1 + 2")

    switch consume result {
    case .value(let value):
      #expect(value.toDouble(in: context) == 3)
    case .exception:
      Issue.record("Expected QuickJS script to evaluate successfully")
    }
  }
}

@Test func quickJSEvaluateScriptReturnsException() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withInstantContext { context in
    let result = context.evaluateScript("throw new Error('boom')")

    switch consume result {
    case .value:
      Issue.record("Expected QuickJS exception result")
    case .exception(let exception):
      let isObject = exception.isObject(in: context)
      let stringValue = exception.toString(in: context)
      #expect(isObject)
      #expect(stringValue == "Error: boom")
    }
  }
}

@Test func quickJSEvaluateScriptSupportsSourceURLAndStartingLine() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withInstantContext { context in
    let result = context.evaluateScript(
      "40 + 2",
      sourceURL: "inline://quickjs-test.js",
      startingLineNumber: 12
    )

    switch consume result {
    case .value(let value):
      #expect(value.toDouble(in: context) == 42)
    case .exception:
      Issue.record("Expected QuickJS script with sourceURL to evaluate successfully")
    }
  }
}

@Test func quickJSInstallsAndCallsGlobalFunction() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withInstantContext { context in
    context.installGlobalFunction(named: "bump") { context, _, arguments in
      let value = arguments.unpack(at: 0, using: JSDefaultConverter<Double>.self, in: context)
      return .value(context.makeNumber(value + 1))
    }

    let result = context.evaluateScript("bump(41)")

    switch consume result {
    case .value(let value):
      #expect(value.toDouble(in: context) == 42)
    case .exception:
      Issue.record("Expected QuickJS-installed global function to be callable")
    }
  }
}

@Test func quickJSFunction() async {
  let context = JSContext<QuickJSEngine>()

  await context.withInstantContext { context in
    let function = context.makeFunction(
      named: "bump",
      callback: { context, thisValue, arguments in
        let value = arguments.unpack(at: 0, using: JSDefaultConverter<Double>.self, in: context)
        return .value(context.makeNumber(value + 1))
      }
    )

    let result = function.call(arguments: 41, in: context)

    switch consume result {
    case .value(let value):
      #expect(value.toDouble(in: context) == 42)
    case .exception:
      Issue.record("Expected QuickJS function to be callable")
    }

  }
}
