import SwiftJavaScript
import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

enum ScriptEngine: String, CaseIterable, CustomStringConvertible, Sendable {
  case javaScriptCore = "JavaScriptCore"
  case quickJS = "QuickJS"

  var description: String { rawValue }

  func run<Assertion: ScriptEngineAssertion>(_ assertion: Assertion.Type) async {
    switch self {
    case .javaScriptCore:
      await assertion.run(JavaScriptCoreEngine.self)
    case .quickJS:
      await assertion.run(QuickJSEngine.self)
    }
  }

  func run<E: JSEngine>(_ engine: E.Type, action: (E.Type) async -> Void) async
  where E.Engine == E {
    await action(engine)
  }
}

protocol ScriptEngineAssertion {
  static func run<E: JSEngine>(_ engine: E.Type) async where E.Engine == E
}

@Suite
struct EngineRuntimeTests {

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
  func makeFunctionReturnsCallableValue(_ engine: ScriptEngine) async {
    await engine.run(MakeFunctionReturnsCallableValue.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func setGetHasDeletePropertyWithStringKey(_ engine: ScriptEngine) async {
    await engine.run(SetGetHasDeletePropertyWithStringKey.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func setGetHasDeletePropertyWithValueKey(_ engine: ScriptEngine) async {
    await engine.run(SetGetHasDeletePropertyWithValueKey.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyAttributesAreRespected(_ engine: ScriptEngine) async {
    await engine.run(PropertyAttributesAreRespected.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyNamesReturnOwnEnumerableStringAndIndexKeys(_ engine: ScriptEngine) async {
    await engine.run(PropertyNamesReturnOwnEnumerableStringAndIndexKeys.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func setGetPropertyAtIndex(_ engine: ScriptEngine) async {
    await engine.run(SetGetPropertyAtIndex.self)
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
  func valueInitializersAndTypePredicates(_ engine: ScriptEngine) async {
    await engine.run(ValueInitializersAndTypePredicates.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func valueEqualityOperators(_ engine: ScriptEngine) async {
    await engine.run(ValueEqualityOperators.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func arrayDateAndInstanceOfPredicates(_ engine: ScriptEngine) async {
    await engine.run(ArrayDateAndInstanceOfPredicates.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func arrayBufferAndTypedArrayBehavior(_ engine: ScriptEngine) async {
    await engine.run(ArrayBufferAndTypedArrayBehavior.self)
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

    #expect(!QuickJSEngine.capabilities.supportsHostObjects)
    #expect(!QuickJSEngine.capabilities.supportsESModules)
    #expect(!QuickJSEngine.capabilities.supportsPromiseJobQueueControl)
  }

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
      let script = JSStringManaged<E>("40 + 2")
      let sourceURL = JSStringManaged<E>("inline://multi-engine-test.js")
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

private enum InstantContextSupportsNativeModuleStyleGlobalHelpers: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let answerKey = "answer"
      context.setGlobalProperty(41, forKey: answerKey)
      let hasAnswer = context.hasGlobalProperty(answerKey)
      let answer = context.getGlobalProperty(forKey: answerKey).toDouble(in: context)
      #expect(hasAnswer)
      #expect(answer == 41)

      let object = context.makeObject()
      let flagKey = JSStringManaged<E>("flag")
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

private enum MakeFunctionReturnsCallableValue: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let function = context.makeFunction(named: "bump") { context, _, arguments in
        let value = arguments.unpack(at: 0, using: JSDefaultConverter<Double>.self, in: context)
        return .value(context.makeNumber(value + 1))
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

private enum SetGetHasDeletePropertyWithStringKey: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let key = JSStringManaged<E>("strKey")
      object.setProperty(3.5, forKey: key, in: context)

      let hasBeforeDelete = object.hasProperty(key, in: context)
      let readIsNumber = object.getProperty(forKey: key, in: context).isNumber(in: context)
      #expect(hasBeforeDelete)
      #expect(readIsNumber)

      object.deleteProperty(forKey: key, in: context)
      let hasAfterDelete = object.hasProperty(key, in: context)
      #expect(!hasAfterDelete)
    }
  }
}

private enum SetGetHasDeletePropertyWithValueKey: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let key = JSValue(string: "valueKey", in: context)
      object.setProperty("abc", forKey: key, in: context)

      let hasBeforeDelete = object.hasProperty(key, in: context)
      let readIsString = object.getProperty(forKey: key, in: context).isString(in: context)
      #expect(hasBeforeDelete)
      #expect(readIsString)

      object.deleteProperty(forKey: key, in: context)
      let hasAfterDelete = object.hasProperty(key, in: context)
      #expect(!hasAfterDelete)
    }
  }
}

private enum PropertyAttributesAreRespected: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = JSValue(objectIn: context)

      object.setProperty(11, forKey: "stringLocked", with: [.readOnly], in: context)
      object.setProperty(13, forKey: "stringLocked", in: context)
      let stringLockedValue = object.getProperty(forKey: "stringLocked", in: context)
        .toInt32(in: context)
      #expect(stringLockedValue == 11)

      object.setProperty(17, forKey: "stringHidden", with: [.dontEnum], in: context)
      object.setProperty(19, forKey: "stringPinned", with: [.dontDelete], in: context)

      let lockedKey = JSValue(string: "locked", in: context)
      object.setProperty(7, forKey: lockedKey, with: [.readOnly], in: context)
      object.setProperty(9, forKey: lockedKey, in: context)
      let lockedValue = object.getProperty(forKey: lockedKey, in: context).toInt32(in: context)
      #expect(lockedValue == 7)

      let hiddenKey = JSValue(string: "hidden", in: context)
      object.setProperty(1, forKey: hiddenKey, with: [.dontEnum], in: context)

      let pinnedKey = JSValue(string: "pinned", in: context)
      object.setProperty(2, forKey: pinnedKey, with: [.dontDelete], in: context)

      context.withGlobalObject { global in
        global.setProperty(object, forKey: "attributeObject", in: context)
      }
      let hiddenEnumerated = context.evaluateScript(
        "Object.keys(attributeObject).includes('hidden')"
      )
      let stringHiddenEnumerated = context.evaluateScript(
        "Object.keys(attributeObject).includes('stringHidden')"
      )
      let pinnedDeleted = context.evaluateScript("delete attributeObject.pinned")
      let pinnedStillPresent = context.evaluateScript("'pinned' in attributeObject")
      let stringPinnedDeleted = context.evaluateScript("delete attributeObject.stringPinned")
      let stringPinnedStillPresent = context.evaluateScript("'stringPinned' in attributeObject")

      switch consume hiddenEnumerated {
      case .value(let value):
        let isHiddenEnumerated = value.toBool(in: context)
        #expect(!isHiddenEnumerated)
      case .exception:
        Issue.record("Expected Object.keys check for hidden value-key property")
      }

      switch consume stringHiddenEnumerated {
      case .value(let value):
        let isHiddenEnumerated = value.toBool(in: context)
        #expect(!isHiddenEnumerated)
      case .exception:
        Issue.record("Expected Object.keys check for hidden string-key property")
      }

      switch consume pinnedDeleted {
      case .value(let value):
        let didDeletePinned = value.toBool(in: context)
        #expect(!didDeletePinned)
      case .exception:
        Issue.record("Expected delete check for pinned value-key property")
      }

      switch consume pinnedStillPresent {
      case .value(let value):
        let isPinnedStillPresent = value.toBool(in: context)
        #expect(isPinnedStillPresent)
      case .exception:
        Issue.record("Expected membership check for pinned value-key property")
      }

      switch consume stringPinnedDeleted {
      case .value(let value):
        let didDeletePinned = value.toBool(in: context)
        #expect(!didDeletePinned)
      case .exception:
        Issue.record("Expected delete check for pinned string-key property")
      }

      switch consume stringPinnedStillPresent {
      case .value(let value):
        let isPinnedStillPresent = value.toBool(in: context)
        #expect(isPinnedStillPresent)
      case .exception:
        Issue.record("Expected membership check for pinned string-key property")
      }
    }
  }
}

private enum PropertyNamesReturnOwnEnumerableStringAndIndexKeys: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let objectResult = context.evaluateScript(
        """
        (() => {
          const parent = { inherited: 1 };
          const object = Object.create(parent);
          object.visible = 2;
          object[3] = 3;
          Object.defineProperty(object, 'hidden', { value: 4, enumerable: false });
          object[Symbol('symbolKey')] = 5;
          return object;
        })()
        """
      )

      switch consume objectResult {
      case .value(let object):
        _ = context.evaluateScript("Object.keys = () => ['patched']")
        let names =
          E.propertyNamesForHandle(
            on: object.borrowHandle(),
            in: context.driverContextHandle
          ) ?? []
        #expect(names == ["3", "visible"])
      case .exception:
        Issue.record("Expected propertyNames fixture object")
      }
    }
  }
}

private enum SetGetPropertyAtIndex: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      object.setProperty(true, at: 2, in: context)
      let readIsBoolean = object.getProperty(at: 2, in: context).isBoolean(in: context)
      #expect(readIsBoolean)
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
        let invokeResult = object.invokeMethod(JSStringManaged<E>("mul"), arguments: 5, in: context)
        switch consume invokeResult {
        case .value(let value):
          let resultValue = value.toDouble(in: context)
          #expect(resultValue == 20)
        case .exception:
          Issue.record("Expected method invocation to succeed")
        }

        let missingResult = object.invokeMethod(JSStringManaged<E>("missing"), in: context)
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
      let function = context.makeFunction(named: "explode") { context, _, _ in
        .exception(context.makeString("boom"))
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

private enum ArrayBufferAndTypedArrayBehavior: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let buffer = JSArrayBuffer<E>(copying: [10, 20, 30, 40, 50, 60], in: context)
      let invalidTypedArrayHandle = buffer.withJSValue { bufferValue in
        E.makeTypedArrayHandle(
          in: context.driverContextHandle,
          kind: .uint16Array,
          arrayBuffer: bufferValue.borrowHandle(),
          byteOffset: 1,
          length: 1
        )
      }
      #expect(invalidTypedArrayHandle == nil)

      let postFailureEvaluation = context.evaluateScript("21 + 21")
      switch consume postFailureEvaluation {
      case .value(let value):
        let result = value.toInt32(in: context)
        #expect(result == 42)
      case .exception:
        Issue.record("Expected typed array construction failure to leave evaluation usable")
      }

      let typedArrayHandle = buffer.withJSValue { bufferValue in
        E.makeTypedArrayHandle(
          in: context.driverContextHandle,
          kind: .uint8Array,
          arrayBuffer: bufferValue.borrowHandle(),
          byteOffset: 2,
          length: 3
        )
      }
      guard let typedArrayHandle else {
        Issue.record("Expected engine to create typed array with ArrayBuffer slice")
        return
      }

      let typedArrayValue = JSValue<E>(handleValue: typedArrayHandle)
      guard let typedArray = JSTypedArray<E>(value: typedArrayValue, in: context) else {
        Issue.record("Expected created value to wrap as JSTypedArray")
        return
      }

      var copiedBytes: [UInt8] = []
      typedArray.withUnsafeBytes { rawBuffer in
        copiedBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }

      let bufferByteLength = buffer.byteLength
      let typedArrayKind = typedArray.kind
      let typedArrayLength = typedArray.length
      let typedArrayByteOffset = typedArray.byteOffset
      let typedArrayByteLength = typedArray.byteLength
      let typedArrayBufferByteLength = typedArray.buffer.byteLength

      #expect(bufferByteLength == 6)
      #expect(typedArrayKind == .uint8Array)
      #expect(typedArrayLength == 3)
      #expect(typedArrayByteOffset == 2)
      #expect(typedArrayByteLength == 3)
      #expect(typedArrayBufferByteLength == 6)
      #expect(copiedBytes == [30, 40, 50])

      let wholeBufferArray = JSTypedArray<E>(
        type: .uint8Array,
        buffer: buffer,
        in: context
      )
      var wholeBufferBytes: [UInt8] = []
      wholeBufferArray.withUnsafeBytes { rawBuffer in
        wholeBufferBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }
      let wholeBufferArrayKind = wholeBufferArray.kind
      let wholeBufferArrayLength = wholeBufferArray.length
      let wholeBufferArrayByteOffset = wholeBufferArray.byteOffset
      let wholeBufferArrayByteLength = wholeBufferArray.byteLength

      #expect(wholeBufferArrayKind == .uint8Array)
      #expect(wholeBufferArrayLength == 6)
      #expect(wholeBufferArrayByteOffset == 0)
      #expect(wholeBufferArrayByteLength == 6)
      #expect(wholeBufferBytes == [10, 20, 30, 40, 50, 60])

      guard
        let lengthConstructedHandle = E.makeTypedArrayHandle(
          in: context.driverContextHandle,
          kind: .uint16Array,
          length: 4
        )
      else {
        Issue.record("Expected engine to create typed array by length")
        return
      }

      let lengthConstructedValue = JSValue<E>(handleValue: lengthConstructedHandle)
      guard let lengthConstructed = JSTypedArray<E>(value: lengthConstructedValue, in: context)
      else {
        Issue.record("Expected length-created value to wrap as JSTypedArray")
        return
      }

      let lengthConstructedKind = lengthConstructed.kind
      let lengthConstructedLength = lengthConstructed.length
      let lengthConstructedByteLength = lengthConstructed.byteLength
      #expect(lengthConstructedKind == .uint16Array)
      #expect(lengthConstructedLength == 4)
      #expect(lengthConstructedByteLength == 8)
    }
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
