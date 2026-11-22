import Testing

@testable import SwiftJavaScript

@Suite
struct EngineInvocationDriverTests {
  @Test(arguments: ScriptEngine.allCases)
  func makeFunctionReturnsCallableValue(_ engine: ScriptEngine) async {
    await engine.run(MakeFunctionReturnsCallableValue.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsValueCallSupportsThisAndArguments(_ engine: ScriptEngine) async {
    await engine.run(JSValueCallSupportsThisAndArguments.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsValueConstructCreatesObject(_ engine: ScriptEngine) async {
    await engine.run(JSValueConstructCreatesObject.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsValueInvokeMethodUsesReceiverAndSurfacesErrors(_ engine: ScriptEngine) async {
    await engine.run(JSValueInvokeMethodUsesReceiverAndSurfacesErrors.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func nativeFunctionNamesAndExceptionsAreObservable(_ engine: ScriptEngine) async {
    await engine.run(NativeFunctionNamesAndExceptionsAreObservable.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func nativeFunctionTransfersReturnedObjectsAndExceptions(_ engine: ScriptEngine) async {
    await engine.run(NativeFunctionTransfersReturnedObjectsAndExceptions.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func arrayDateAndInstanceOfPredicates(_ engine: ScriptEngine) async {
    await engine.run(ArrayDateAndInstanceOfPredicates.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func valueEqualityOperators(_ engine: ScriptEngine) async {
    await engine.run(ValueEqualityOperators.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func valueObjectAndTypeHelpersWork(_ engine: ScriptEngine) async {
    await engine.run(ValueObjectAndTypeHelpersWork.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func objectAndArrayInitializersCreateExpectedKinds(_ engine: ScriptEngine) async {
    await engine.run(ObjectAndArrayInitializersCreateExpectedKinds.self)
  }
}

private enum MakeFunctionReturnsCallableValue: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let function = context.makeFunction(named: "bump") { c, _, arguments in
        let value: Double = arguments.unpack(
          types: Double.self,
          in: c
        )
        return JSCallbackReturn(persistent: c.persist(c.makeNumber(value + 1)))
      }

      let result = function.call(arguments: 41, in: context)
      switch consume result {
      case .value(let value):
        let resultValue = value.toDouble(in: context)
        #expect(resultValue == 42)
      case .exception:
        Issue.record("Expected function value to be callable")
      }
    }
  }
}

private enum JSValueCallSupportsThisAndArguments: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let functionResult = context.evaluateScript("(function(a, b) { return this.base + a + b })")

      switch consume functionResult {
      case .value(let function):
        let thisObject = JSValue(objectIn: context)
        thisObject.setProperty(10, forKey: "base", in: context)

        let callResult = function.call(this: thisObject, arguments: 1, 2, in: context)
        switch consume callResult {
        case .value(let value):
          let resultValue = value.toDouble(in: context)
          #expect(resultValue == 13)
        case .exception:
          Issue.record("Expected function.call to succeed")
        }
      case .exception:
        Issue.record("Expected callable function value")
      }
    }
  }
}

private enum JSValueConstructCreatesObject: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let constructorResult = context.evaluateScript(
        "(function Person(name) { this.name = name; this.kind = 'person' })"
      )

      switch consume constructorResult {
      case .value(let constructor):
        let constructResult = constructor.construct(arguments: "alice", in: context)
        switch consume constructResult {
        case .value(let instance):
          let isObject = instance.isObject(in: context)
          let name = instance.getProperty(forKey: "name", in: context).toString(in: context)
          let kind = instance.getProperty(forKey: "kind", in: context).toString(in: context)
          #expect(isObject)
          #expect(name == "alice")
          #expect(kind == "person")
        case .exception:
          Issue.record("Expected constructor.construct to succeed")
        }
      case .exception:
        Issue.record("Expected constructor function value")
      }
    }
  }
}

private enum JSValueInvokeMethodUsesReceiverAndSurfacesErrors: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let objectResult = context.evaluateScript(
        "({ scale: 4, mul(value) { return this.scale * value } })")

      switch consume objectResult {
      case .value(let object):
        let invokeResult = object.invokeMethod(("mul"), arguments: 5, in: context)
        switch consume invokeResult {
        case .value(let value):
          let resultValue = value.toDouble(in: context)
          #expect(resultValue == 20)
        case .exception:
          Issue.record("Expected method invocation to succeed")
        }

        let missingResult = object.invokeMethod(("missing"), in: context)
        switch consume missingResult {
        case .value:
          Issue.record("Expected missing method invocation to raise exception")
        case .exception(let exception):
          let isObject = exception.isObject(in: context)
          #expect(isObject)
        }
      case .exception(let exception):
        let message = exception.toString(in: context)
        Issue.record("Expected object literal value, got exception: \(message)")
      }
    }
  }
}

private enum NativeFunctionNamesAndExceptionsAreObservable: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let function = context.makeFunction(named: "explode") { c, _, _ in
        return JSCallbackReturn(exception: c.makeString("boom").handle)
      }
      context.withGlobalObject { global in
        global.setProperty(function, forKey: "explode", in: context)
      }

      let nameResult = context.evaluateScript("explode.name")
      switch consume nameResult {
      case .value(let value):
        let functionName = value.toString(in: context)
        #expect(functionName == "explode")
      case .exception:
        Issue.record("Expected native function name to be readable")
      }

      let callResult = context.evaluateScript("explode()")
      switch consume callResult {
      case .value:
        Issue.record("Expected native function exception")
      case .exception(let exception):
        let exceptionString = exception.toString(in: context)
        #expect(exceptionString == "boom")
      }
    }
  }
}

private enum NativeFunctionTransfersReturnedObjectsAndExceptions: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let makeObject = context.makeFunction(named: "makeNativeObject") { c, _, _ in
        let object = c.makePersistentObject()
        object.setProperty("native", forKey: "kind", in: c)
        object.setProperty(7, forKey: "count", in: c)
        return JSCallbackReturn(persistent: object)
      }
      let throwObject = context.makeFunction(named: "throwNativeObject") { c, _, _ in
        guard case .value(let error) = c.makeObject() else {
          return JSCallbackReturn(temporary: c.makeUndefined().handle)
        }
        error.setProperty(c.makeString("native-error"), forKey: "kind")
        error.setProperty(c.makeNumber(13), forKey: "code")
        return c.throw(error)
      }

      context.withGlobalObject { global in
        global.setProperty(makeObject, forKey: "makeNativeObject", in: context)
        global.setProperty(throwObject, forKey: "throwNativeObject", in: context)
      }

      let objectResult = context.evaluateScript(
        """
        const nativeObject = makeNativeObject();
        globalThis.savedNativeObject = nativeObject;
        `${nativeObject.kind}:${nativeObject.count}:${globalThis.savedNativeObject === nativeObject}`;
        """
      )
      switch consume objectResult {
      case .value(let value):
        #expect(value.toString(in: context) == "native:7:true")
      case .exception(let exception):
        Issue.record(
          "Expected native object callback result, got \(exception.toString(in: context))")
      }

      let exceptionResult = context.evaluateScript(
        """
        try {
          throwNativeObject();
          "missing";
        } catch (error) {
          globalThis.savedNativeException = error;
          `${error.kind}:${error.code}:${globalThis.savedNativeException === error}`;
        }
        """
      )
      switch consume exceptionResult {
      case .value(let value):
        #expect(value.toString(in: context) == "native-error:13:true")
      case .exception(let exception):
        Issue.record(
          "Expected native exception callback result, got \(exception.toString(in: context))")
      }
    }
  }
}

private enum ArrayDateAndInstanceOfPredicates: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let arrayResult = context.evaluateScript("[1, 2, 3]")
      let dateResult = context.evaluateScript("new Date(0)")
      let arrayConstructorResult = context.evaluateScript("Array")

      switch consume arrayResult {
      case .value(let array):
        switch consume dateResult {
        case .value(let date):
          switch consume arrayConstructorResult {
          case .value(let arrayConstructor):
            let arrayIsArray = array.isArray(in: context)
            let arrayIsDate = array.isDate(in: context)
            let dateIsDate = date.isDate(in: context)
            let arrayIsInstance = array.isInstanceOf(arrayConstructor, in: context)

            #expect(arrayIsArray)
            #expect(!arrayIsDate)
            #expect(dateIsDate)
            #expect(arrayIsInstance)
          case .exception:
            Issue.record("Expected Array constructor")
          }
        case .exception:
          Issue.record("Expected Date instance")
        }
      case .exception:
        Issue.record("Expected array instance")
      }
    }
  }
}

private enum ValueEqualityOperators: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let oneNumber = JSValue(number: 1, in: context)
      let oneString = JSValue(string: "1", in: context)
      let oneNumberCopy = JSValue(number: 1, in: context)

      let looselyEqual = oneNumber.looselyEquals(oneString, in: context)
      let looselyNotEqual = !oneNumber.looselyEquals(JSValue(number: 2, in: context), in: context)
      let strictlyEqual = oneNumber.strictlyEquals(oneNumberCopy, in: context)
      let strictlyNotEqual = !oneNumber.strictlyEquals(JSValue(number: 2, in: context), in: context)

      #expect(looselyEqual)
      #expect(looselyNotEqual)
      #expect(strictlyEqual)
      #expect(strictlyNotEqual)
    }
  }
}

private enum ValueObjectAndTypeHelpersWork: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let primitive = JSValue(number: 42, in: context)
      let objectResult = primitive.toObject(in: context)
      switch consume objectResult {
      case .value(let object):
        let isObject = object.isObject(in: context)
        #expect(isObject)
      case .exception:
        Issue.record("Expected toObject to box primitive numbers")
      }

      #expect(primitive.toNumber(in: context) == 42)
    }
  }
}

private enum ObjectAndArrayInitializersCreateExpectedKinds: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = JSValue(objectIn: context)
      let array = JSValue(arrayIn: context)
      let objectIsObject = object.isObject(in: context)
      let arrayIsObject = array.isObject(in: context)
      let arrayIsArray = array.isArray(in: context)

      #expect(objectIsObject)
      #expect(arrayIsObject)
      #expect(arrayIsArray)
    }
  }
}
extension JSInstantContext {
  fileprivate func makePersistentObject() -> JSValue<E> {
    let result = makeObject()
    guard case .value(let cb) = result else { preconditionFailure("makeObject failed") }
    return persist(cb)
  }
}
