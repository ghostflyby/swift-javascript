import SwiftJavaScript
import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

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
      runVirtualMachineHashableAndIdentity(JavaScriptCoreEngine.self)
    case .quickJS:
      runVirtualMachineHashableAndIdentity(QuickJSEngine.self)
    }
  }

  @Test(arguments: ScriptEngine.allCases)
  func contextHashableAndGlobalObject(_ engine: ScriptEngine) async {
    switch engine {
    case .javaScriptCore:
      await runContextHashableAndGlobalObject(JavaScriptCoreEngine.self)
    case .quickJS:
      await runContextHashableAndGlobalObject(QuickJSEngine.self)
    }
  }

  @Test(arguments: ScriptEngine.allCases)
  func valuesCanBeUsedAcrossContextsInSameVirtualMachine(_ engine: ScriptEngine) async {
    await engine.run(ValuesCanBeUsedAcrossContextsInSameVirtualMachine.self)
  }

  @Test
  func engineCapabilitiesMatchImplementedPublicSurface() {
    #expect(JavaScriptCoreEngine.capabilities.supportsHostObjects)
    #expect(!JavaScriptCoreEngine.capabilities.supportsESModules)
    #expect(!JavaScriptCoreEngine.capabilities.supportsPromiseJobQueueControl)

    #expect(QuickJSEngine.capabilities.supportsHostObjects)
    #expect(!QuickJSEngine.capabilities.supportsESModules)
    #expect(!QuickJSEngine.capabilities.supportsPromiseJobQueueControl)
  }
}

private enum EngineContextDataKey: JSContextDataKey {
  typealias Value = String
}

private enum EvaluateScriptReturnsValueForValidScript: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let result = context.evaluateScript("1 + 2")

      switch consume result {
      case .value(let value):
        let resultValue = value.toDouble(in: context)
        #expect(resultValue == 3)
      case .exception:
        Issue.record("Expected script to evaluate successfully")
      }
    }
  }
}

private enum EvaluateScriptSupportsSourceURL: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

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
        let resultValue = value.toDouble(in: context)
        #expect(resultValue == 42)
      case .exception:
        Issue.record("Expected script with sourceURL to evaluate successfully")
      }
    }
  }
}

private enum EvaluateScriptReturnsExceptionForThrowingScript: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let result = context.evaluateScript("throw new Error('boom')", sourceURL: "inline://throw.js")

      switch consume result {
      case .value:
        Issue.record("Expected JavaScript exception")
      case .exception(let exception):
        let isObject = exception.isObject(in: context)
        #expect(isObject)
        if E.self == QuickJSEngine.self {
          let message = exception.toString(in: context)
          #expect(message == "Error: boom")
        }
      }
    }
  }
}

private enum ContextDataIsSharedWithInstantContextAndCallbacks: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.setData("actor", for: EngineContextDataKey.self)
    let instantValue: String? = await context.withInstantContext {
      $0.data(for: EngineContextDataKey.self)
    }
    #expect(instantValue == "actor")

    let callbackValue = await context.withInstantContext { context in
      let function = context.makeFunction(named: "readContextData") { context, _, _ in
        let value = context.data(for: EngineContextDataKey.self) ?? "missing"
        _ = context.makeFunction(named: "nested") { context, _, _ in
          .value(context.makeUndefined())
        }
        return .value(context.makeString(value))
      }
      let result = function.call(in: context)
      switch consume result {
      case .value(let value):
        return value.toString(in: context)
      case .exception:
        Issue.record("Expected context data callback to return a value")
        return "exception"
      }
    }

    #expect(callbackValue == "actor")

    await context.withInstantContext {
      $0.setData("instant", for: EngineContextDataKey.self)
    }
    let actorValue: String? = await context.data(for: EngineContextDataKey.self)

    #expect(actorValue == "instant")
  }
}

private enum InstantContextSupportsNativeModuleStyleGlobalHelpers: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let answerKey: StaticString = "answer"
      context.setGlobalProperty(41, forKey: answerKey)
      let hasAnswer = context.hasGlobalProperty(answerKey)
      let answer = context.getGlobalProperty(forKey: answerKey).toDouble(in: context)
      #expect(hasAnswer)
      #expect(answer == 41)

      let object = context.makeObject()
      let flagKey: StaticString = "flag"
      object.setProperty(context.makeBoolean(true), forKey: flagKey, in: context)
      let flag = object.getProperty(forKey: flagKey, in: context).toBool(in: context)
      #expect(flag)

      context.installGlobalFunction(named: "bump") { context, _, arguments in
        let value = arguments.unpack(at: 0, using: JSDefaultConverter<Double>.self, in: context)
        return .value(context.makeNumber(value + 1))
      }

      let result = context.evaluateScript("bump(answer)")
      switch consume result {
      case .value(let value):
        let resultValue = value.toDouble(in: context)
        #expect(resultValue == 42)
      case .exception:
        Issue.record("Expected installed global function to be callable")
      }

      context.deleteGlobalProperty(forKey: answerKey)
      let hasAnswerAfterDelete = context.hasGlobalProperty(answerKey)
      #expect(!hasAnswerAfterDelete)
    }
  }
}

private enum ContextThinWrapsInstantContextGlobalHelpers: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withIsolatedGlobalObject { context, _ in
      let countKey: StaticString = "count"
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
}

private enum ValueInitializersAndTypePredicates: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let undefined = JSValue(undefinedIn: context)
      let null = JSValue(nullIn: context)
      let bool = JSValue(boolean: true, in: context)
      let number = JSValue(number: 42, in: context)
      let string = JSValue(string: "abc", in: context)
      let symbol = JSValue(symbol: "s", in: context)
      let intNumber = JSValue(number: 7 as Int, in: context)

      let undefinedIsUndefined = undefined.isUndefined(in: context)
      let undefinedType = undefined.type(in: context)
      let nullIsNull = null.isNull(in: context)
      let nullType = null.type(in: context)
      let boolIsBoolean = bool.isBoolean(in: context)
      let boolType = bool.type(in: context)
      let numberIsNumber = number.isNumber(in: context)
      let numberType = number.type(in: context)
      let stringIsString = string.isString(in: context)
      let stringType = string.type(in: context)
      let symbolIsSymbol = symbol.isSymbol(in: context)
      let symbolType = symbol.type(in: context)
      let intIsNumber = intNumber.isNumber(in: context)
      let intIsBigInt = intNumber.isBigInt(in: context)

      #expect(undefinedIsUndefined)
      #expect(undefinedType == .undefined)
      #expect(nullIsNull)
      #expect(nullType == .null)
      #expect(boolIsBoolean)
      #expect(boolType == .boolean)
      #expect(numberIsNumber)
      #expect(numberType == .number)
      #expect(stringIsString)
      #expect(stringType == .string)
      #expect(symbolIsSymbol)
      #expect(symbolType == .symbol)
      #expect(intIsNumber)
      #expect(!intIsBigInt)
    }
  }
}

private func runVirtualMachineHashableAndIdentity<E: JSEngine>(_: E.Type)
where E.Engine == E, E.RuntimeHandle: Hashable {
  let vm1 = JSVirtualMachine<E>()
  let vm2 = JSVirtualMachine<E>()

  #expect(vm1 == vm1)
  #expect(vm1 != vm2)
  #expect(vm1.hashValue == vm1.hashValue)
}

private func runContextHashableAndGlobalObject<E: JSEngine>(_: E.Type) async
where E.Engine == E, E.ContextHandle: Hashable {
  let vm = JSVirtualMachine<E>()
  let context1 = JSContext(virtualMachine: vm)
  let context2 = JSContext(virtualMachine: vm)

  #expect(context1 == context1)
  #expect(context1 != context2)

  await context1.withIsolatedGlobalObject { context, global in
    let isObject = global.isObject(in: context)
    let type = global.type(in: context)
    #expect(isObject)
    #expect(type == .object)
  }
}

private enum ValuesCanBeUsedAcrossContextsInSameVirtualMachine: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let virtualMachine = JSVirtualMachine<E>()
    guard
      let sourceContext = E.makeBorrowedContextHandleFromRuntime(
        in: virtualMachine.driverRuntimeHandle),
      let targetContext = E.makeBorrowedContextHandleFromRuntime(
        in: virtualMachine.driverRuntimeHandle),
      let value = E.makeNumberValueHandle(7, sourceContext)
    else {
      Issue.record("Expected same-VM driver handles to be creatable")
      return
    }
    defer {
      _ = value.releaseReference()
      _ = targetContext.releaseReference()
      _ = sourceContext.releaseReference()
    }

    let isCompatible = E.isValueHandleCompatibleWithContext(value, in: targetContext)
    let targetValue = E.toNumberForHandle(value, in: targetContext)

    #expect(isCompatible)
    #expect(targetValue == 7)
  }
}
