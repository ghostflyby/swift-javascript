import Testing

@testable import SwiftJavaScript
@testable import SwiftyQuickJS

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

// MARK: - QJSValue core surface (S4)
//
// Mirror of `JSCValueCoreTests` on the reference-counted engine. The arena
// owns every creation reference; the non-owning value views stay valid only
// while the scope below is alive, so each test keeps using the scope after its
// final value read.
//
// Calls on the `~Copyable` value view are evaluated into Copyable results
// before `#expect`, which captures its subject.

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
struct QJSValueCoreTests {
  private func makeContext() -> (QJSRuntimeHandle, QJSContextHandle) {
    let runtime = QJSEngine.makeRuntimeHandle()
    guard let context = QJSEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
      preconditionFailure("QJSEngine could not create a context handle")
    }
    return (runtime, context)
  }

  private func makeObject(
    in context: QJSContextHandle,
    on scope: borrowing QJSInstantContext
  ) -> QJSValue {
    guard let result = context.makeObjectResultHandle() else {
      preconditionFailure("QJSEngine could not create an object")
    }
    switch consume result {
    case .value(let handle):
      return scope.adoptCreatedHandle(handle)
    case .exception(let handle):
      context.releaseCreatedHandle(handle)
      preconditionFailure("QJSEngine object creation returned an exception")
    }
  }

  @Test
  func classifiesAndConvertsPrimitives() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)

      let undefined = scope.adoptCreatedHandle(context.makeUndefinedValueHandle()!)
      let undefinedType = undefined.type()
      let undefinedText = undefined.toString()
      let undefinedNumber = undefined.toNumber()
      let undefinedTruth = undefined.toBoolean()
      #expect(undefinedType == .undefined)
      #expect(undefinedText == "undefined")
      #expect(undefinedNumber.isNaN)
      #expect(!undefinedTruth)
      #expect(predicates(undefined) == [true, false, false, false, false, false, false, false])

      let null = scope.adoptCreatedHandle(context.makeNullValueHandle()!)
      let nullType = null.type()
      let nullText = null.toString()
      let nullNumber = null.toNumber()
      let nullTruth = null.toBoolean()
      #expect(nullType == .null)
      #expect(nullText == "null")
      #expect(nullNumber == 0)
      #expect(!nullTruth)
      #expect(predicates(null) == [false, true, false, false, false, false, false, false])

      let trueValue = scope.adoptCreatedHandle(context.makeBooleanValueHandle(true)!)
      let falseValue = scope.adoptCreatedHandle(context.makeBooleanValueHandle(false)!)
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

      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(42.5)!)
      let numberType = number.type()
      let numberText = number.toString()
      let numberValue = number.toNumber()
      let numberTruth = number.toBoolean()
      let zero = scope.adoptCreatedHandle(context.makeNumberValueHandle(0)!)
      let zeroTruth = zero.toBoolean()
      #expect(numberType == .number)
      #expect(numberText == "42.5")
      #expect(numberValue == 42.5)
      #expect(numberTruth)
      #expect(!zeroTruth)
      #expect(predicates(number) == [false, false, false, true, false, false, false, false])

      let string = scope.adoptCreatedHandle(context.makeStringValueHandle("hello")!)
      let stringType = string.type()
      let stringText = string.toString()
      let stringNumber = string.toNumber()
      let stringTruth = string.toBoolean()
      let empty = scope.adoptCreatedHandle(context.makeStringValueHandle("")!)
      let emptyTruth = empty.toBoolean()
      #expect(stringType == .string)
      #expect(stringText == "hello")
      #expect(stringNumber.isNaN)
      #expect(stringTruth)
      #expect(!emptyTruth)
      #expect(predicates(string) == [false, false, false, false, true, false, false, false])

      let symbol = scope.adoptCreatedHandle(context.makeSymbolValueHandle("surface")!)
      let symbolType = symbol.type()
      let symbolTruth = symbol.toBoolean()
      #expect(symbolType == .symbol)
      #expect(symbolTruth)
      #expect(predicates(symbol) == [false, false, false, false, false, true, false, false])

      let bigInt: QJSValue
      guard let script = context.makePreparedScriptHandle("1n"),
        let result = context.evaluatePreparedScriptResultHandle(
          script,
          sourceURL: nil,
          startingLineNumber: 1
        )
      else {
        preconditionFailure("QJSEngine could not prepare a BigInt literal")
      }
      switch consume result {
      case .value(let handle):
        bigInt = scope.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle))
      case .exception(let handle):
        context.releaseCreatedHandle(QJSOwnedValueHandle.adopting(handle))
        preconditionFailure("QJSEngine could not evaluate a BigInt literal")
      }
      let bigIntType = bigInt.type()
      #expect(bigIntType == .bigInt)
      #expect(predicates(bigInt) == [false, false, false, false, false, false, false, true])

      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  @Test
  func equalityUsesJavaScriptOperators() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)

      let one = scope.adoptCreatedHandle(context.makeNumberValueHandle(1)!)
      let oneAgain = scope.adoptCreatedHandle(context.makeNumberValueHandle(1)!)
      let oneString = scope.adoptCreatedHandle(context.makeStringValueHandle("1")!)
      let two = scope.adoptCreatedHandle(context.makeNumberValueHandle(2)!)

      let strictlySame = one.strictlyEquals(oneAgain)
      let strictlyDifferentTypes = one.strictlyEquals(oneString)
      let looselySame = one.looselyEquals(oneString)
      let looselyDifferent = one.looselyEquals(two)
      #expect(strictlySame)
      #expect(!strictlyDifferentTypes)
      #expect(looselySame)
      #expect(!looselyDifferent)

      let nan = scope.adoptCreatedHandle(context.makeNumberValueHandle(.nan)!)
      let nanAgain = scope.adoptCreatedHandle(context.makeNumberValueHandle(.nan)!)
      let nanStrictlyEqual = nan.strictlyEquals(nanAgain)
      let nanLooselyEqual = nan.looselyEquals(nanAgain)
      #expect(!nanStrictlyEqual)
      #expect(!nanLooselyEqual)

      let object = makeObject(in: context, on: scope)
      let otherObject = makeObject(in: context, on: scope)
      let objectHandle = object.borrowHandle()
      let sameObjectView = QJSValue(
        handle: objectHandle,
        contextHandle: context
      )
      let sameObjectStrict = object.strictlyEquals(sameObjectView)
      let sameObjectLoose = object.looselyEquals(sameObjectView)
      let distinctObjects = object.strictlyEquals(otherObject)
      #expect(sameObjectStrict)
      #expect(sameObjectLoose)
      #expect(!distinctObjects)

      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  @Test
  func constructsViewsFromArenaHandles() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)

      let number: QJSValue = scope.adoptCreatedHandle(context.makeNumberValueHandle(7)!)
      let anchored: QJSValue = scope.anchorBorrowedHandle(number.borrowHandle())
      let anchoredMatches = anchored.strictlyEquals(number)
      #expect(anchoredMatches)

      let numberHandle = number.borrowHandle()
      let direct = QJSValue(
        handle: numberHandle,
        contextHandle: context
      )
      let directHandle = direct.borrowHandle()
      let directMatches = direct.strictlyEquals(number)
      #expect(directHandle == numberHandle)
      #expect(directMatches)

      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  /// The S4 identity note: `QJSValueHandle` equality must compare the whole
  /// 8-byte union payload, not just `u.int32`. Two handles whose low 32 bits
  /// agree but whose high 32 bits differ are distinct values.
  @Test
  func valueHandleIdentityComparesAllEightBytes() {
    var lhs = CQuickJSValue()
    lhs.tag = Int64(JS_TAG_OBJECT)
    lhs.u.ptr = UnsafeMutableRawPointer(bitPattern: 0x1_0000_0001)

    var rhs = lhs
    rhs.u.ptr = UnsafeMutableRawPointer(bitPattern: 0x2_0000_0001)

    let lhsHandle = QJSValueHandle(ref: lhs)
    let rhsHandle = QJSValueHandle(ref: rhs)

    #expect(lhsHandle != rhsHandle)
  }

  @Test
  func decodesThroughSurfaceWitnesses() throws {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)

      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(3.5)!)
      let integer = scope.adoptCreatedHandle(context.makeNumberValueHandle(7)!)
      let string = scope.adoptCreatedHandle(context.makeStringValueHandle("hello")!)
      let boolean = scope.adoptCreatedHandle(context.makeBooleanValueHandle(true)!)

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

      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  /// Slice 2: indexed access is a value-level requirement implemented by the
  /// engine value against `getIndexPropertyHandle`/`setIndexPropertyHandle`.
  @Test
  func readsAndWritesIndexedProperties() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)
      let object = makeObject(in: context, on: scope)

      let missing = object.getProperty(at: 0, in: scope)
      switch consume missing {
      case .value(let value):
        let isUndefined = value.isUndefined()
        #expect(isUndefined)
      case .exception:
        Issue.record("index read of a fresh object returned an exception")
      }

      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(9)!)
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

      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  /// Slice 2: `localValue` hands back the view of an arena-backed callback
  /// value without claiming or tracking anything.
  @Test
  func exposesLocalValueViewsWithoutClaiming() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)
      let callback = scope.makeString("local")
      let local = scope.localValue(callback)
      let localText = local.toString()
      let matchesCallbackText = localText == callback.toString()
      #expect(localText == "local")
      #expect(matchesCallbackText)
      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }
}
