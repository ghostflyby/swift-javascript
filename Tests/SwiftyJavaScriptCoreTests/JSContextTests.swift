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
      let result = context.makeNumber(value * 2)
      return .value(JSValue(retaining: result))
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

@Test func contextGlobalPropertyGetterThrowNormalizesToUndefined() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let install = context.evaluateScript(
      """
      Object.defineProperty(globalThis, "boom", {
        configurable: true,
        get() { throw new Error("boom") }
      })
      """
    )

    switch consume install {
    case .value:
      break
    case .exception:
      Issue.record("Expected throwing getter installation to succeed")
      return
    }

    let value = context.getGlobalProperty(forKey: "boom")
    #expect(value.isUndefined(in: context))
  }
}
