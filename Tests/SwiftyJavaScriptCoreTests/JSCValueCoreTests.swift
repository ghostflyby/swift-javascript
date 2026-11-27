import JavaScriptCore
import Testing

@testable import SwiftJavaScript
@testable import SwiftyJavaScriptCore

// MARK: - JSCValue core surface (S4)
//
// Classification, conversion, equality, and the two construction paths
// (`adoptCreatedHandle`/`anchorBorrowedHandle` and the raw-ref bridge). The
// property/invocation surface is S5.
//
// `JSValue` is `~Copyable`, and Swift Testing's `#expect` captures a method's
// receiver, so every call on a value view is evaluated into a Copyable result
// before the assertion.

private func predicates<V: SwiftJavaScript.JSValue & ~Copyable>(
  _ value: borrowing V
) -> [Bool] {
  [
    value.isUndefined(),
    value.isNull(),
    value.isBoolean(),
    value.isNumber(),
    value.isString(),
    value.isSymbol(),
    value.isObject(),
    value.isBigInt(),
  ]
}

@Suite
struct JSCValueCoreTests {
  private func makeContext() -> (JSContextGroupRef, JSGlobalContextRef) {
    let runtime = JSContextGroupCreate()!
    guard let context = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
      preconditionFailure("JSCEngine could not create a context handle")
    }
    return (runtime, context)
  }

  private func makeObject(
    in context: JSGlobalContextRef,
    on scope: borrowing JSCInstantContext
  ) -> JSCValue {
    guard let result = javaScriptCoreMakeObjectResultHandle(context) else {
      preconditionFailure("JSCEngine could not create an object")
    }
    switch consume result {
    case .value(let handle):
      return scope.adoptCreatedHandle(handle)
    case .exception(let handle):

      preconditionFailure("JSCEngine object creation returned an exception")
    }
  }

  @Test
  func classifiesAndConvertsPrimitives() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)

      let undefined = scope.adoptCreatedHandle(javaScriptCoreMakeUndefinedValueHandle(context)!)
      let undefinedType = undefined.type()
      let undefinedText = undefined.toString()
      let undefinedNumber = undefined.toNumber()
      let undefinedTruth = undefined.toBoolean()
      #expect(undefinedType == .undefined)
      #expect(undefinedText == "undefined")
      #expect(undefinedNumber.isNaN)
      #expect(!undefinedTruth)
      #expect(predicates(undefined) == [true, false, false, false, false, false, false, false])

      let null = scope.adoptCreatedHandle(javaScriptCoreMakeNullValueHandle(context)!)
      let nullType = null.type()
      let nullText = null.toString()
      let nullNumber = null.toNumber()
      let nullTruth = null.toBoolean()
      #expect(nullType == .null)
      #expect(nullText == "null")
      #expect(nullNumber == 0)
      #expect(!nullTruth)
      #expect(predicates(null) == [false, true, false, false, false, false, false, false])

      let trueValue = scope.adoptCreatedHandle(javaScriptCoreMakeBooleanValueHandle(true, context)!)
      let falseValue = scope.adoptCreatedHandle(
        javaScriptCoreMakeBooleanValueHandle(false, context)!)
      let trueType = trueValue.type()
      let trueText = trueValue.toString()
      let trueNumber = trueValue.toNumber()
      let trueTruth = trueValue.toBoolean()
      let falseTruth = falseValue.toBoolean()
      #expect(trueType == .boolean)
      #expect(trueText == "true")
      #expect(trueNumber == 1)
      #expect(trueTruth)
      #expect(!falseTruth)
      #expect(predicates(trueValue) == [false, false, true, false, false, false, false, false])

      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(42.5, context)!)
      let numberType = number.type()
      let numberText = number.toString()
      let numberValue = number.toNumber()
      let numberTruth = number.toBoolean()
      let zero = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(0, context)!)
      let zeroTruth = zero.toBoolean()
      #expect(numberType == .number)
      #expect(numberText == "42.5")
      #expect(numberValue == 42.5)
      #expect(numberTruth)
      #expect(!zeroTruth)
      #expect(predicates(number) == [false, false, false, true, false, false, false, false])

      let string = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("hello", context)!)
      let stringType = string.type()
      let stringText = string.toString()
      let stringNumber = string.toNumber()
      let stringTruth = string.toBoolean()
      let empty = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("", context)!)
      let emptyTruth = empty.toBoolean()
      #expect(stringType == .string)
      #expect(stringText == "hello")
      #expect(stringNumber.isNaN)
      #expect(stringTruth)
      #expect(!emptyTruth)
      #expect(predicates(string) == [false, false, false, false, true, false, false, false])

      let symbol = scope.adoptCreatedHandle(
        javaScriptCoreMakeSymbolValueHandle("surface", context)!)
      let symbolType = symbol.type()
      let symbolTruth = symbol.toBoolean()
      #expect(symbolType == .symbol)
      #expect(symbolTruth)
      #expect(predicates(symbol) == [false, false, false, false, false, true, false, false])

      var bigIntRef: JSValueRef?
      withJavaScriptCoreString("1n") { sourceRef in
        var exception: JSValueRef?
        guard
          let ref = JSEvaluateScript(context, sourceRef, nil, nil, 1, &exception),
          exception == nil
        else {
          preconditionFailure("JavaScriptCore could not evaluate a BigInt literal")
        }
        bigIntRef = ref
      }
      if let bigIntRef {
        let bigInt = JSCValue(ref: bigIntRef, in: scope)
        let bigIntType = bigInt.type()
        #expect(bigIntType == .bigInt)
        #expect(predicates(bigInt) == [false, false, false, false, false, false, false, true])
      } else {
        Issue.record("JavaScriptCore did not produce a BigInt value")
      }

      // Keep the scope (and thus its arena) alive through every read above.
      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func equalityUsesJavaScriptOperators() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)

      let one = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(1, context)!)
      let oneAgain = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(1, context)!)
      let oneString = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("1", context)!)
      let two = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(2, context)!)

      let strictlySame = one.strictlyEquals(oneAgain)
      let strictlyDifferentTypes = one.strictlyEquals(oneString)
      let looselySame = one.looselyEquals(oneString)
      let looselyDifferent = one.looselyEquals(two)
      #expect(strictlySame)
      #expect(!strictlyDifferentTypes)
      #expect(looselySame)
      #expect(!looselyDifferent)

      let nan = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(.nan, context)!)
      let nanAgain = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(.nan, context)!)
      let nanStrictlyEqual = nan.strictlyEquals(nanAgain)
      let nanLooselyEqual = nan.looselyEquals(nanAgain)
      #expect(!nanStrictlyEqual)
      #expect(!nanLooselyEqual)

      let object = makeObject(in: context, on: scope)
      let otherObject = makeObject(in: context, on: scope)
      let sameObjectView = JSCValue(
        ref: object.ref,
        contextRef: context
      )
      let sameObjectStrict = object.strictlyEquals(sameObjectView)
      let sameObjectLoose = object.looselyEquals(sameObjectView)
      let distinctObjects = object.strictlyEquals(otherObject)
      #expect(sameObjectStrict)
      #expect(sameObjectLoose)
      #expect(!distinctObjects)

      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func constructsViewsFromArenaHandlesAndRawReferences() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)

      let number: JSCValue = scope.adoptCreatedHandle(
        javaScriptCoreMakeNumberValueHandle(7, context)!)
      let anchored: JSCValue = scope.anchorBorrowedHandle(number.ref)
      let anchoredMatches = anchored.strictlyEquals(number)
      #expect(anchoredMatches)

      let expectedRef = number.ref
      let rawView = JSCValue(ref: expectedRef, in: scope)
      let rawRef = rawView.ref
      let borrowedRef = rawView.ref
      let rawMatches = rawView.strictlyEquals(number)
      #expect(rawRef == expectedRef)
      #expect(borrowedRef == expectedRef)
      #expect(rawMatches)

      let result: JSResult<JSCValue> = .value(number)
      switch result.toPrivateResult() {
      case .value(let ref):
        #expect(ref == expectedRef)
      case .exception:
        Issue.record("expected a value result")
      }

      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func decodesThroughSurfaceWitnesses() throws {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)

      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(3.5, context)!)
      let integer = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(7, context)!)
      let string = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("hello", context)!)
      let boolean = scope.adoptCreatedHandle(javaScriptCoreMakeBooleanValueHandle(true, context)!)

      let decodedString = String(value: string, in: scope)
      let strictlyDecodedString = try String.tryDecode(string, in: scope)
      let decodedNumber = Double(value: number, in: scope)
      let strictlyDecodedNumber = try Double.tryDecode(number, in: scope)
      let decodedInt = try Int32.tryDecode(integer, in: scope)
      let decodedUInt = try UInt32.tryDecode(integer, in: scope)
      let decodedBool = Bool(value: boolean, in: scope)
      let strictlyDecodedBool = try Bool.tryDecode(boolean, in: scope)
      #expect(decodedString == "hello")
      #expect(strictlyDecodedString == "hello")
      #expect(decodedNumber == 3.5)
      #expect(strictlyDecodedNumber == 3.5)
      #expect(decodedInt == 7)
      #expect(decodedUInt == 7)
      #expect(decodedBool)
      #expect(strictlyDecodedBool)

      do {
        _ = try String.tryDecode(number, in: scope)
        Issue.record("String decode should reject a number")
      } catch {
        #expect(error is JSValueConversionError)
      }

      do {
        _ = try Bool.tryDecode(number, in: scope)
        Issue.record("Bool decode should reject a number")
      } catch {
        #expect(error is JSValueConversionError)
      }

      do {
        _ = try Int32.tryDecode(number, in: scope)
        Issue.record("Int32 decode should reject a non-integer number")
      } catch {
        #expect(error is JSValueConversionError)
      }

      do {
        _ = try Never.tryDecode(number, in: scope)
        Issue.record("Never decode must always fail")
      } catch {
        #expect(error is JSValueConversionError)
      }

      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  /// Slice 2: indexed access is a value-level requirement implemented by the
  /// engine value against `getIndexPropertyHandle`/`setIndexPropertyHandle`.
  @Test
  func readsAndWritesIndexedProperties() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let object = makeObject(in: context, on: scope)

      let missing = object.getProperty(at: 0, in: scope)
      switch consume missing {
      case .value(let value):
        let isUndefined = value.isUndefined()
        #expect(isUndefined)
      case .exception:
        Issue.record("index read of a fresh object returned an exception")
      }

      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(9, context)!)
      let didSet = object.setProperty(at: 1, to: number, in: scope)
      let read = object.getProperty(at: 1, in: scope)
      let hasIndex = object.hasProperty("1", in: scope)
      #expect(didSet)
      #expect(hasIndex)
      switch consume read {
      case .value(let value):
        let numberValue = value.toNumber()
        #expect(numberValue == 9)
      case .exception:
        Issue.record("index read returned an exception")
      }

      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  /// Slice 2: `localValue` hands back the view of an arena-backed callback
  /// value without claiming or tracking anything.
  @Test
  func exposesLocalValueViewsWithoutClaiming() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let callback = scope.makeString("local")
      let local = scope.localValue(callback)
      let localText = local.toString()
      let matchesCallbackText = localText == callback.toString()
      #expect(localText == "local")
      #expect(matchesCallbackText)
      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }
}
