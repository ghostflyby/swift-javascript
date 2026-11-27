import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

@testable import SwiftJavaScript

@Suite
struct EngineInvocationDriverTests {
  @Test(arguments: ScriptEngine.allCases)
  func makeFunctionReturnsCallableValue(_ engine: ScriptEngine) async {
    await engine.run(MakeFunctionReturnsCallableValue.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func surfaceFunctionCallbackEntryIsCallable(_ engine: ScriptEngine) async {
    switch engine {
    case .javaScriptCore:
      await runSurfaceFunctionCallbackEntry(JSCContext.self)
    case .quickJS:
      await runSurfaceFunctionCallbackEntry(QJSContext.self)
    }
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
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let function = scope.makeFunction(named: "bump") { c, _, arguments in
        let value: Double = arguments.withValue(at: 0, in: c) { $0.toNumber() }
        return c.return(c.persist(c.makeNumber(value + 1)))
      }

      let result = function.call(
        arguments: [scope.makeNumber(41).asCallArgument()], in: scope)
      switch consume result {
      case .value(let value):
        #expect(value.toNumber() == 42)
      case .exception:
        Issue.record("Expected function value to be callable")
      }
    }
  }
}

private enum JSValueCallSupportsThisAndArguments: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let functionResult = scope.evaluateScript("(function(a, b) { return this.base + a + b })")

      switch consume functionResult {
      case .value(let function):
        let thisObject: C.Value
        switch scope.makeObject() {
        case .value(let objectCallback):
          thisObject = scope.persist(objectCallback)
        case .exception:
          Issue.record("Expected makeObject to succeed")
          return
        }
        let base = scope.persist(scope.makeNumber(10))
        thisObject.setProperty("base", to: base, attributes: .none, in: scope)

        let callResult = function.call(
          this: thisObject,
          arguments: [
            scope.persist(scope.makeNumber(1)).asCallArgument(),
            scope.persist(scope.makeNumber(2)).asCallArgument(),
          ],
          in: scope
        )
        switch consume callResult {
        case .value(let value):
          #expect(value.toNumber() == 13)
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
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let constructorResult = scope.evaluateScript(
        "(function Person(name) { this.name = name; this.kind = 'person' })"
      )

      switch consume constructorResult {
      case .value(let constructor):
        let constructResult = constructor.construct(
          arguments: [scope.makeString("alice").asCallArgument()], in: scope)
        switch consume constructResult {
        case .value(let instance):
          let isObject = instance.isObject()
          let nameResult = instance.getProperty("name", in: scope)
          let kindResult = instance.getProperty("kind", in: scope)
          guard case .value(let name) = nameResult, case .value(let kind) = kindResult else {
            Issue.record("Expected constructor instance properties")
            return
          }
          #expect(isObject)
          #expect(name.toString() == "alice")
          #expect(kind.toString() == "person")
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
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let objectResult = scope.evaluateScript(
        "({ scale: 4, mul(value) { return this.scale * value } })")

      switch consume objectResult {
      case .value(let object):
        let invokeResult = object.invokeMethod(
          "mul", arguments: [scope.makeNumber(5).asCallArgument()], in: scope)
        switch consume invokeResult {
        case .value(let value):
          #expect(value.toNumber() == 20)
        case .exception:
          Issue.record("Expected method invocation to succeed")
        }

        let missingResult = object.invokeMethod("missing", arguments: [], in: scope)
        switch consume missingResult {
        case .value:
          Issue.record("Expected missing method invocation to raise exception")
        case .exception(let exception):
          let isObject = exception.isObject()
          #expect(isObject)
        }
      case .exception(let exception):
        Issue.record("Expected object literal value, got exception: \(exception.toString())")
      }
    }
  }
}

private enum NativeFunctionNamesAndExceptionsAreObservable: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let function = scope.makeFunction(named: "explode") { c, _, _ in
        return c.throw(c.makeString("boom"))
      }
      scope.setGlobalProperty(function, forKey: "explode", with: .none)

      let nameResult = scope.evaluateScript("explode.name")
      switch consume nameResult {
      case .value(let value):
        #expect(value.toString() == "explode")
      case .exception:
        Issue.record("Expected native function name to be readable")
      }

      let callResult = scope.evaluateScript("explode()")
      switch consume callResult {
      case .value:
        Issue.record("Expected native function exception")
      case .exception(let exception):
        #expect(exception.toString() == "boom")
      }
    }
  }
}

private enum NativeFunctionTransfersReturnedObjectsAndExceptions: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let makeObject = scope.makeFunction(named: "makeNativeObject") { c, _, _ in
        switch c.makeObject() {
        case .value(let objectCallback):
          let object = c.persist(objectCallback)
          object.setProperty("kind", to: c.makeString("native"), attributes: .none, in: c)
          object.setProperty("count", to: c.makeNumber(7), attributes: .none, in: c)
          return c.return(object)
        case .exception:
          return c.throwUndefined()
        }
      }
      let throwObject = scope.makeFunction(named: "throwNativeObject") { c, _, _ in
        let made = c.makeObject()
        switch consume made {
        case .value(let errorCallback):
          let error = c.persist(errorCallback)
          error.setProperty("kind", to: c.makeString("native-error"), attributes: .none, in: c)
          error.setProperty("code", to: c.makeNumber(13), attributes: .none, in: c)
          return c.throw(error)
        case .exception:
          return c.throwUndefined()
        }
      }

      scope.setGlobalProperty(makeObject, forKey: "makeNativeObject", with: .none)
      scope.setGlobalProperty(throwObject, forKey: "throwNativeObject", with: .none)

      let objectResult = scope.evaluateScript(
        """
        const nativeObject = makeNativeObject();
        globalThis.savedNativeObject = nativeObject;
        `${nativeObject.kind}:${nativeObject.count}:${globalThis.savedNativeObject === nativeObject}`;
        """
      )
      switch consume objectResult {
      case .value(let value):
        #expect(value.toString() == "native:7:true")
      case .exception(let exception):
        Issue.record(
          "Expected native object callback result, got \(exception.toString())")
      }

      let exceptionResult = scope.evaluateScript(
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
        #expect(value.toString() == "native-error:13:true")
      case .exception(let exception):
        Issue.record(
          "Expected native exception callback result, got \(exception.toString())")
      }
    }
  }
}

private enum ArrayDateAndInstanceOfPredicates: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let arrayResult = scope.evaluateScript("[1, 2, 3]")
      let dateResult = scope.evaluateScript("new Date(0)")
      let arrayConstructorResult = scope.evaluateScript("Array")

      switch consume arrayResult {
      case .value(let array):
        switch consume dateResult {
        case .value(let date):
          switch consume arrayConstructorResult {
          case .value(let arrayConstructor):
            let arrayIsArray = array.isArray(in: scope)
            let arrayIsDate = array.isDate(in: scope)
            let dateIsDate = date.isDate(in: scope)
            let arrayIsInstance = array.isInstanceOf(arrayConstructor, in: scope)

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
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let oneNumber = scope.persist(scope.makeNumber(1))
      let oneString = scope.persist(scope.makeString("1"))
      let oneNumberCopy = scope.persist(scope.makeNumber(1))
      let twoNumber = scope.persist(scope.makeNumber(2))
      _ = scope

      let looselyEqual = oneNumber.looselyEquals(oneString)
      let looselyNotEqual = !oneNumber.looselyEquals(twoNumber)
      let strictlyEqual = oneNumber.strictlyEquals(oneNumberCopy)
      let strictlyNotEqual = !oneNumber.strictlyEquals(twoNumber)

      #expect(looselyEqual)
      #expect(looselyNotEqual)
      #expect(strictlyEqual)
      #expect(strictlyNotEqual)
    }
  }
}

private enum ValueObjectAndTypeHelpersWork: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let primitive = scope.persist(scope.makeNumber(42))
      let objectResult = primitive.toObject(in: scope)
      switch consume objectResult {
      case .value(let object):
        let isObject = object.isObject()
        #expect(isObject)
      case .exception:
        Issue.record("Expected toObject to box primitive numbers")
      }

      #expect(primitive.toNumber() == 42)
    }
  }
}

private enum ObjectAndArrayInitializersCreateExpectedKinds: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let objectCallback: C.Value
      switch scope.makeObject() {
      case .value(let made):
        objectCallback = made
      case .exception:
        Issue.record("Expected object creation to succeed")
        return
      }
      let arrayCallback: C.Value
      switch scope.makeArray() {
      case .value(let made):
        arrayCallback = made
      case .exception:
        Issue.record("Expected array creation to succeed")
        return
      }
      let object = scope.persist(objectCallback)
      let array = scope.persist(arrayCallback)
      let objectIsObject = object.isObject()
      let objectIsArray = object.isArray(in: scope)
      let arrayIsObject = array.isObject()
      let arrayIsArray = array.isArray(in: scope)

      #expect(objectIsObject)
      #expect(!objectIsArray)
      #expect(arrayIsObject)
      #expect(arrayIsArray)
    }
  }
}

// MARK: - Surface callback entry (S6)
//
// The engine-level function factory takes the surface callback signature; this
// test drives it end to end and echoes an argument back so the value-level
// carrier contract is exercised through the public callback faces.

private final class SurfaceCallbackObservations: @unchecked Sendable {
  var argumentCount: Int? = nil
  var thisType: JSType? = nil
  var firstArgumentText: String? = nil
}

private func runSurfaceFunctionCallbackEntry<C: JSContext>(
  _: C.Type
) async {
  let observations = SurfaceCallbackObservations()
  let context = await makeContext(C.self)

  await context.withInstantContext { scope in
    let callback: JSFunctionCallback<C.InstantContext> = {
      callbackContext, thisValue, arguments in
      observations.argumentCount = arguments.count
      observations.thisType = thisValue.type()
      return arguments.withValue(at: 0, in: callbackContext) { value in
        observations.firstArgumentText = value.toString()
        return callbackContext.return(value)
      }
    }

    let function = scope.makeFunction(named: "surfaceEcho", callback: callback)

    let result = function.call(
      arguments: [scope.makeString("echoed").asCallArgument()], in: scope)
    switch consume result {
    case .value(let value):
      #expect(value.toString() == "echoed")
    case .exception(let exception):
      Issue.record("Surface callback entry raised \(exception.toString())")
    }
  }

  #expect(observations.argumentCount == 1)
  #expect(observations.firstArgumentText == "echoed")
}
