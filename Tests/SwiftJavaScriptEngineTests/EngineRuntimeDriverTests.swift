import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

@testable import SwiftJavaScript

@Suite
struct EngineRuntimeDriverTests {
  @Test(arguments: ScriptEngine.allCases)
  func evaluateScriptReturnsValueForValidScript(_ engine: ScriptEngine) async {
    await engine.run(EvaluateScriptReturnsValueForValidScript.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func evaluateScriptSupportsSourceURL(_ engine: ScriptEngine) async {
    await engine.run(EvaluateScriptSupportsSourceURL.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func evaluateScriptReturnsExceptionForThrowingScript(_ engine: ScriptEngine) async {
    await engine.run(EvaluateScriptReturnsExceptionForThrowingScript.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func instantContextSupportsNativeModuleStyleGlobalHelpers(_ engine: ScriptEngine) async {
    await engine.run(InstantContextSupportsNativeModuleStyleGlobalHelpers.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func contextThinWrapsInstantContextGlobalHelpers(_ engine: ScriptEngine) async {
    await engine.run(ContextThinWrapsInstantContextGlobalHelpers.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func contextDataIsSharedWithInstantContextAndCallbacks(_ engine: ScriptEngine) async {
    await engine.run(ContextDataIsSharedWithInstantContextAndCallbacks.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func valueInitializersAndTypePredicates(_ engine: ScriptEngine) async {
    await engine.run(ValueInitializersAndTypePredicates.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func virtualMachineHashableAndIdentity(_ engine: ScriptEngine) async {
    switch engine {
    case .javaScriptCore:
      runVirtualMachineHashableAndIdentity(JSCContext.self)
    case .quickJS:
      runVirtualMachineHashableAndIdentity(QJSContext.self)
    }
  }

  @Test(arguments: ScriptEngine.allCases)
  func contextHashableAndGlobalObject(_ engine: ScriptEngine) async {
    switch engine {
    case .javaScriptCore:
      await runContextHashableAndGlobalObject(JSCContext.self)
    case .quickJS:
      await runContextHashableAndGlobalObject(QJSContext.self)
    }
  }

  @Test
  func engineCapabilitiesMatchImplementedPublicSurface() {
    expectTrue(JSCEngine.capabilities.supportsHostObjects)
    expectTrue(!JSCEngine.capabilities.supportsESModules)
    expectTrue(!JSCEngine.capabilities.supportsPromiseJobQueueControl)

    expectTrue(QJSEngine.capabilities.supportsHostObjects)
    expectTrue(!QJSEngine.capabilities.supportsESModules)
    expectTrue(!QJSEngine.capabilities.supportsPromiseJobQueueControl)
  }
}

private enum EngineContextDataKey: JSContextDataKey {
  typealias Value = String
}

private enum EvaluateScriptReturnsValueForValidScript: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { context in
      let result = context.evaluateScript("1 + 2")

      switch consume result {
      case .value(let value):
        let resultValue = value.toNumber()
        expectTrue(resultValue == 3)
      case .exception:
        Issue.record("Expected script to evaluate successfully")
      }
    }
  }
}

private enum EvaluateScriptSupportsSourceURL: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { context in
      let script = "40 + 2"
      let sourceURL = "inline://multi-engine-test.js"
      let result = context.evaluateScript(
        script,
        sourceURL: sourceURL,
        startingLineNumber: 12
      )

      switch consume result {
      case .value(let value):
        let resultValue = value.toNumber()
        expectTrue(resultValue == 42)
      case .exception:
        Issue.record("Expected script with sourceURL to evaluate successfully")
      }
    }
  }
}

private enum EvaluateScriptReturnsExceptionForThrowingScript: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { context in
      let result = context.evaluateScript("throw new Error('boom')", sourceURL: "inline://throw.js")

      switch consume result {
      case .value:
        Issue.record("Expected JavaScript exception")
      case .exception(let exception):
        let isObject = exception.isObject()
        expectTrue(isObject)
        if C.self == QJSContext.self {
          let message = exception.toString()
          expectTrue(message == "Error: boom")
        }
      }
    }
  }
}

private enum ContextDataIsSharedWithInstantContextAndCallbacks: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.setData("actor", for: EngineContextDataKey.self)
    let instantValue: String? = await context.withInstantContext {
      $0.data(for: EngineContextDataKey.self)
    }
    expectTrue(instantValue == "actor")

    let callbackValue = await context.withInstantContext { ic in
      let function = ic.makeFunction(named: "readContextData") { c, _, _ in
        let value = c.data(for: EngineContextDataKey.self) ?? "missing"
        _ = c.makeFunction(named: "nested") { c2, _, _ in
          c2.returnUndefined()
        }
        return c.return(c.persist(c.makeString(value)))
      }
      let result = function.call(arguments: [], in: ic)
      switch consume result {
      case .value(let value):
        return value.toString()
      case .exception:
        Issue.record("Expected context data callback to return a value")
        return "exception"
      }
    }

    expectTrue(callbackValue == "actor")

    await context.withInstantContext {
      $0.setData("instant", for: EngineContextDataKey.self)
    }
    let actorValue: String? = await context.data(for: EngineContextDataKey.self)

    expectTrue(actorValue == "instant")
  }
}

private enum InstantContextSupportsNativeModuleStyleGlobalHelpers: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let answerKey: StaticString = "answer"
      scope.setGlobalProperty(Int32(41), forKey: answerKey, with: .none)
      let hasAnswer = scope.hasGlobalProperty(answerKey)
      let answer = scope.getGlobalProperty(forKey: answerKey).toNumber()
      expectTrue(hasAnswer)
      expectTrue(answer == 41)

      let objectCallback: C.CallbackValue
      switch scope.makeObject() {
      case .value(let made):
        objectCallback = made
      case .exception:
        Issue.record("Expected makeObject to succeed")
        return
      }
      let object = scope.persist(objectCallback)
      let flagKey: StaticString = "flag"
      object.setProperty(
        flagKey, to: scope.makeBoolean(true), attributes: .none, in: scope)
      let flagResult = object.getProperty(flagKey, in: scope)
      guard case .value(let flag) = flagResult else {
        Issue.record("Expected flag property read")
        return
      }
      expectTrue(flag.toBoolean())

      scope.installGlobalFunction(named: "bump") { c, _, arguments in
        let value: Double = arguments.withValue(at: 0, in: c) { $0.toNumber() }
        return c.return(c.persist(c.makeNumber(value + 1)))
      }

      let result = scope.evaluateScript("bump(answer)")
      switch consume result {
      case .value(let value):
        expectTrue(value.toNumber() == 42)
      case .exception:
        Issue.record("Expected installed global function to be callable")
      }

      scope.deleteGlobalProperty(forKey: answerKey)
      let hasAnswerAfterDelete = scope.hasGlobalProperty(answerKey)
      expectTrue(!hasAnswerAfterDelete)
    }
  }
}

private enum ContextThinWrapsInstantContextGlobalHelpers: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let countKey: StaticString = "count"
      scope.setGlobalProperty(Int32(5), forKey: countKey, with: .none)
      let hasCount = scope.hasGlobalProperty(countKey)
      expectTrue(hasCount)

      scope.installGlobalFunction(named: "double") { c, _, arguments in
        let value: Double = arguments.withValue(at: 0, in: c) { $0.toNumber() }
        return c.return(c.persist(c.makeNumber(value * 2)))
      }

      let result = scope.evaluateScript("double(count)")
      switch consume result {
      case .value(let value):
        expectTrue(value.toNumber() == 10)
      case .exception:
        Issue.record("Expected the context thin wrappers to install callable globals")
      }

      let count = scope.getGlobalProperty(forKey: countKey)
      expectTrue(count.toNumber() == 5)

      scope.deleteGlobalProperty(forKey: countKey)
      let hasCountAfterDelete = scope.hasGlobalProperty(countKey)
      expectTrue(!hasCountAfterDelete)
    }
  }
}

private enum ValueInitializersAndTypePredicates: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let undefined = scope.makeUndefined()
      let null = scope.makeNull()
      let bool = scope.makeBoolean(true)
      let number = scope.makeNumber(42)
      let string = scope.makeString("abc")
      let symbol = scope.makeSymbol("s")
      let intNumber = scope.makeNumber(7 as Int)

      let undefinedIsUndefined = undefined.isUndefined()
      let undefinedType = undefined.type()
      let nullIsNull = null.isNull()
      let nullType = null.type()
      let boolIsBoolean = bool.isBoolean()
      let boolType = bool.type()
      let numberIsNumber = number.isNumber()
      let numberType = number.type()
      let stringIsString = string.isString()
      let stringType = string.type()
      let symbolIsSymbol = symbol.isSymbol()
      let symbolType = symbol.type()
      let intIsNumber = intNumber.isNumber()
      let intIsBigInt = intNumber.isBigInt()

      expectTrue(undefinedIsUndefined)
      expectTrue(undefinedType == .undefined)
      expectTrue(nullIsNull)
      expectTrue(nullType == .null)
      expectTrue(boolIsBoolean)
      expectTrue(boolType == .boolean)
      expectTrue(numberIsNumber)
      expectTrue(numberType == .number)
      expectTrue(stringIsString)
      expectTrue(stringType == .string)
      expectTrue(symbolIsSymbol)
      expectTrue(symbolType == .symbol)
      expectTrue(intIsNumber)
      expectTrue(!intIsBigInt)
    }
  }
}

private func runVirtualMachineHashableAndIdentity<C: JSContext>(_: C.Type) {
  let vm1 = C.VirtualMachine()
  let vm2 = C.VirtualMachine()

  expectTrue(vm1 == vm1)
  expectTrue(vm1 != vm2)
  expectTrue(vm1.hashValue == vm1.hashValue)
}

private func runContextHashableAndGlobalObject<C: JSContext>(_: C.Type) async {
  let vm = C.VirtualMachine()
  let context1 = C(virtualMachine: vm)
  let context2 = C(virtualMachine: vm)

  expectTrue(context1 == context1)
  expectTrue(context1 != context2)

  await context1.withInstantContext { scope in
    let global = scope.globalObjectValue()
    expectTrue(global.isObject())
    expectTrue(global.type() == .object)
  }
}

// MARK: - Cross-context values
//
// "A value created on one context handle can be read through a sibling context
// handle of the same runtime" is a raw driver property: it needs two context
// handles and a borrowed value token, and the public protocol surface no
// longer names either. The coverage lives in the two concrete engine targets
// (`JSCContextSurfaceTests`/`QJSContextSurfaceTests`).

/// `#expect` cannot capture the non-copyable surface value views; binding the
/// boolean first keeps the macro on a plain `Bool`.
private func expectTrue(
  _ condition: Bool,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(condition, sourceLocation: sourceLocation)
}
