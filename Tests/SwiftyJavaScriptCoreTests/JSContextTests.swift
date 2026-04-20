import Testing

@testable import SwiftyJavaScriptCore

@Test func contextThinWrapsInstantContextGlobalHelpers() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let countKey = "count"
    context.setGlobalProperty(5, forKey: countKey)
    let hasCount = context.hasGlobalProperty(countKey)
    #expect(hasCount)

    context.installGlobalFunction(named: "double") { context, _, arguments in
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
