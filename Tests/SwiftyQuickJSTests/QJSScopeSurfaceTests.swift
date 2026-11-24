import Testing

@testable import SwiftJavaScript
@testable import SwiftyQuickJS

// MARK: - QuickJS surface scopes (S7)
//
// Mirror of `JSCScopeSurfaceTests` on the reference-counted engine. The
// window arena owns the creation reference; `persist` moves it to the outer
// scope, which is what the post-window reads below rely on.

private struct QJSScopePayload: Codable, Equatable {
  var name: String
  var count: Int
  var items: [Double]
  var nested: Nested

  struct Nested: Codable, Equatable {
    var flag: Bool
  }
}

private enum QJSScopeDataKey: JSContextDataKey {
  typealias Value = String
}

@Suite
struct QJSScopeSurfaceTests {
  private func makeContext() -> (QJSRuntimeHandle, QJSContextHandle) {
    let runtime = QJSEngine.makeRuntimeHandle()
    guard let context = QJSEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
      preconditionFailure("QJSEngine could not create a context handle")
    }
    return (runtime, context)
  }

  @Test
  func factoriesProduceExpectedPrimitives() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    let stringType = scope.makeString("hello").type()
    let numberType = scope.makeNumber(3.5).type()
    let booleanType = scope.makeBoolean(true).type()
    let nullType = scope.makeNull().type()
    let undefinedType = scope.makeUndefined().type()
    let symbolType = scope.makeSymbol("sym").type()

    #expect(stringType == .string)
    #expect(numberType == .number)
    #expect(booleanType == .boolean)
    #expect(nullType == .null)
    #expect(undefinedType == .undefined)
    #expect(symbolType == .symbol)

    let object = scope.makeObject()
    switch consume object {
    case .value(let object):
      let isObject = object.isObject()
      let persisted = scope.persist(object)
      let isArray = persisted.isArray(in: scope)
      #expect(isObject)
      #expect(!isArray)
    case .exception:
      Issue.record("makeObject returned an exception")
    }

    let array = scope.makeArray()
    switch consume array {
    case .value(let array):
      let persisted = scope.persist(array)
      let isArray = persisted.isArray(in: scope)
      #expect(isArray)
    case .exception:
      Issue.record("makeArray returned an exception")
    }
  }

  @Test
  func persistMovesValueIntoTheOuterScope() {
    let (runtime, context) = makeContext()
    _ = runtime

    var outer = QJSScope(handle: context)
    outer.open()

    let persistedHandle: QJSValueHandle
    let persistedContext: QJSContextHandle
    do {
      let inner = QJSInstantContext(handle: context)
      let persisted = inner.persist(inner.makeString("kept"))
      persistedHandle = persisted.borrowHandle()
      persistedContext = persisted.contextHandle
      let inside = persisted.toString()
      #expect(inside == "kept")
    }

    // The inner window drained; the outer scope's arena now owns the value.
    let revived = QJSValue(handle: persistedHandle, contextHandle: persistedContext)
    let text = revived.toString()
    #expect(text == "kept")
  }

  @Test
  func nestedWindowsKeepTheOuterArenaAlive() {
    let (runtime, context) = makeContext()
    _ = runtime

    var outer = QJSScope(handle: context)
    outer.open()

    do {
      let first = QJSInstantContext(handle: context)
      let outerValue = first.persist(first.makeNumber(1))
      #expect(outerValue.toNumber() == 1)

      do {
        let second = QJSInstantContext(handle: context)
        let innerValue = second.persist(second.makeNumber(2))
        #expect(innerValue.toNumber() == 2)
      }

      let stillAlive = outerValue.toNumber()
      #expect(stillAlive == 1)
    }

    let text = outer.makeString("after").toString()
    #expect(text == "after")
  }

  @Test
  func returnAndThrowCarryTheExpectedFlags() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    let returned = scope.return(scope.makeString("ok"))
    let returnedIsException = returned.isException
    let returnedHandle = returned.borrowHandle()
    #expect(!returnedIsException)
    #expect(QJSValue(handle: returnedHandle, contextHandle: context).toString() == "ok")

    let thrown = scope.throw(scope.makeString("boom"))
    let thrownIsException = thrown.isException
    let thrownHandle = thrown.borrowHandle()
    #expect(thrownIsException)
    #expect(QJSValue(handle: thrownHandle, contextHandle: context).toString() == "boom")

    let undefinedReturn = scope.returnUndefined()
    let undefinedReturnIsException = undefinedReturn.isException
    #expect(!undefinedReturnIsException)

    let undefinedThrow = scope.throwUndefined()
    let undefinedThrowIsException = undefinedThrow.isException
    #expect(undefinedThrowIsException)

    let promoted = scope.return(scope.persist(scope.makeBoolean(true)))
    let promotedIsException = promoted.isException
    #expect(!promotedIsException)
  }

  @Test
  func globalPropertyReadWriteDelete() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)
    let answer: StaticString = "answer"

    scope.setGlobalProperty(scope.makeNumber(41), forKey: answer)
    let hasAnswer = scope.hasGlobalProperty(answer)
    let readBack = scope.getGlobalProperty(forKey: answer)
    let readNumber = readBack.toNumber()
    #expect(hasAnswer)
    #expect(readNumber == 41)

    let label: StaticString = "label"
    scope.setGlobalProperty("surface" as String, forKey: label)
    let labelText = scope.getGlobalProperty(forKey: label).toString()
    #expect(labelText == "surface")

    scope.deleteGlobalProperty(forKey: answer)
    let hasAfterDelete = scope.hasGlobalProperty(answer)
    let missingText = scope.getGlobalProperty(forKey: answer).toString()
    #expect(!hasAfterDelete)
    #expect(missingText == "undefined")

    let globalObject = scope.globalObjectValue()
    let globalIsObject = globalObject.isObject()
    #expect(globalIsObject)
  }

  @Test
  func scriptEvaluationThroughPreparedAndSourceForms() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    let prepared = scope.prepareScript("6 * 7")
    let preparedResult = scope.evaluateScript(
      prepared,
      sourceURL: nil,
      startingLineNumber: 1
    )
    switch consume preparedResult {
    case .value(let value):
      let number = value.toNumber()
      #expect(number == 42)
    case .exception:
      Issue.record("prepared script evaluation threw")
    }

    let sourceResult = scope.evaluateScript("'a' + 'b'")
    switch consume sourceResult {
    case .value(let value):
      let text = value.toString()
      #expect(text == "ab")
    case .exception:
      Issue.record("source script evaluation threw")
    }
  }

  @Test
  func functionCallbackUsesTheSurfaceWindow() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    scope.installGlobalFunction(named: "double") { callbackContext, _, arguments in
      let value = arguments.withValue(at: 0, in: callbackContext) { argument in
        argument.toNumber()
      }
      return callbackContext.return(callbackContext.makeNumber(value * 2))
    }

    let result = scope.evaluateScript("double(21)")
    switch consume result {
    case .value(let value):
      let doubled = value.toNumber()
      #expect(doubled == 42)
    case .exception:
      Issue.record("installed surface function threw")
    }

    let made = scope.makeFunction(named: "five") { callbackContext, _, _ in
      callbackContext.return(callbackContext.makeNumber(5))
    }
    let callResult = made.call(arguments: [], in: scope)
    switch consume callResult {
    case .value(let value):
      let number = value.toNumber()
      #expect(number == 5)
    case .exception:
      Issue.record("makeFunction result was not callable")
    }
  }

  @Test
  func surfaceEncoderWitnessesProduceValues() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    let boolean = true.toSurfaceValue(in: scope)
    let string = "encoded".toSurfaceValue(in: scope)
    let double = Double(2.5).toSurfaceValue(in: scope)
    let int32 = Int32(7).toSurfaceValue(in: scope)
    let uint32 = UInt32(9).toSurfaceValue(in: scope)

    let booleanType = boolean.type()
    let stringText = string.toString()
    let doubleNumber = double.toNumber()
    let int32Number = int32.toNumber()
    let uint32Number = uint32.toNumber()
    #expect(booleanType == .boolean)
    #expect(stringText == "encoded")
    #expect(doubleNumber == 2.5)
    #expect(int32Number == 7)
    #expect(uint32Number == 9)
  }

  @Test
  func codableConverterTraversesSurfaceObjects() throws {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    let payload = QJSScopePayload(
      name: "surface",
      count: 3,
      items: [1.5, 2.5],
      nested: .init(flag: true)
    )
    let encoded = try JSCodableValueConverter<QJSScopePayload>.tryEncode(payload, in: scope)

    let name = encoded.getProperty("name", in: scope)
    switch consume name {
    case .value(let value):
      let text = value.toString()
      #expect(text == "surface")
    case .exception:
      Issue.record("encoded object lost its name property")
    }

    let nested = encoded.getProperty("nested", in: scope)
    switch consume nested {
    case .value(let value):
      let flag = value.getProperty("flag", in: scope)
      switch consume flag {
      case .value(let flagValue):
        let isTrue = flagValue.toBoolean()
        #expect(isTrue)
      case .exception:
        Issue.record("nested object lost its flag property")
      }
    case .exception:
      Issue.record("encoded object lost its nested property")
    }

    let decoded = try JSCodableValueConverter<QJSScopePayload>.tryDecode(encoded, in: scope)
    #expect(decoded == payload)
  }

  @Test
  func simpleValueInitializersPersistIntoTheDefaultScope() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = QJSInstantContext(handle: context)

    let string = QJSValue(string: "initial", in: scope)
    let number = QJSValue(number: 12, in: scope)
    let boolean = QJSValue(boolean: false, in: scope)
    let object = QJSValue(objectIn: scope)
    let array = QJSValue(arrayIn: scope)

    let stringText = string.toString()
    let numberValue = number.toNumber()
    let booleanType = boolean.type()
    let objectType = object.type()
    let arrayIsArray = array.isArray(in: scope)
    #expect(stringText == "initial")
    #expect(numberValue == 12)
    #expect(booleanType == .boolean)
    #expect(objectType == .object)
    #expect(arrayIsArray)
  }

  @Test
  func contextDataIsSharedWithTheWindow() {
    let (runtime, context) = makeContext()
    _ = runtime
    // A bare engine context has no host-installed storage box; install one to
    // exercise the scope's data pass-through.
    context.installContextDataStorageBox(JSContextDataStorageBox())
    let scope = QJSInstantContext(handle: context)

    scope.setData("shared", for: QJSScopeDataKey.self)
    let value = scope.data(for: QJSScopeDataKey.self)
    #expect(value == "shared")

    scope.setData(nil, for: QJSScopeDataKey.self)
    let cleared = scope.data(for: QJSScopeDataKey.self)
    #expect(cleared == nil)
  }
}
