import SwiftJavaScript
import Testing

@testable import SwiftyQuickJS

// MARK: - Context-free QuickJS values and inputs
//
// QuickJS immediates (undefined, null, booleans, integers and doubles) carry
// their whole payload in the tagged value. They need no runtime or context;
// the tests below exercise conversion, equality, property use and persistent
// minting without creating one.

@Suite
struct QJSContextFreeValueTests {
  @Test
  func immediateValuesClassifyAndConvertWithoutAContext() {
    let undefined = QJSValue.undefined
    let null = QJSValue.null
    let boolean = QJSValue(boolean: true)
    let number = QJSValue(number: 42.5)
    let integer = QJSValue(number: 42)

    let undefinedType = undefined.type()
    let undefinedText = undefined.toString()
    let undefinedNumber = undefined.toNumber()
    let undefinedTruth = undefined.toBoolean()
    #expect(undefinedType == .undefined)
    #expect(undefinedText == "undefined")
    #expect(undefinedNumber.isNaN)
    #expect(!undefinedTruth)

    let nullType = null.type()
    let nullText = null.toString()
    let nullNumber = null.toNumber()
    let nullTruth = null.toBoolean()
    #expect(nullType == .null)
    #expect(nullText == "null")
    #expect(nullNumber == 0)
    #expect(!nullTruth)

    let booleanType = boolean.type()
    let booleanText = boolean.toString()
    let booleanNumber = boolean.toNumber()
    let booleanTruth = boolean.toBoolean()
    #expect(booleanType == .boolean)
    #expect(booleanText == "true")
    #expect(booleanNumber == 1)
    #expect(booleanTruth)

    let numberType = number.type()
    let numberText = number.toString()
    let numberValue = number.toNumber()
    let numberTruth = number.toBoolean()
    #expect(numberType == .number)
    #expect(numberText == "42.5")
    #expect(numberValue == 42.5)
    #expect(numberTruth)

    let integerType = integer.type()
    let integerText = integer.toString()
    let integerValue = integer.toNumber()
    #expect(integerType == .number)
    #expect(integerText == "42")
    #expect(integerValue == 42)
  }

  @Test
  func numberTextMatchesECMAScriptFormatting() {
    let negativeZero = QJSValue(number: -0.0).toString()
    let large = QJSValue(number: 1e21).toString()
    let tiny = QJSValue(number: 1e-7).toString()
    let small = QJSValue(number: 0.000001).toString()
    let infinity = QJSValue(number: Double.infinity).toString()
    let negativeInfinity = QJSValue(number: -Double.infinity).toString()
    let nan = QJSValue(number: Double.nan).toString()
    #expect(negativeZero == "0")
    #expect(large == "1e+21")
    #expect(tiny == "1e-7")
    #expect(small == "0.000001")
    #expect(infinity == "Infinity")
    #expect(negativeInfinity == "-Infinity")
    #expect(nan == "NaN")
  }

  @Test
  func immediateEqualityUsesJavaScriptOperators() {
    let oneInt = QJSValue(number: 1)
    let oneDouble = QJSValue(number: 1.0)
    let two = QJSValue(number: 2)
    let truth = QJSValue(boolean: true)
    let lie = QJSValue(boolean: false)
    let nan = QJSValue(number: Double.nan)
    let otherNan = QJSValue(number: Double.nan)
    let null = QJSValue.null
    let undefined = QJSValue.undefined

    let intStrictlyEqualsDouble = oneInt.strictlyEquals(oneDouble)
    let intLooselyEqualsDouble = oneInt.looselyEquals(oneDouble)
    let intStrictlyEqualsTwo = oneInt.strictlyEquals(two)
    let truthLooselyEqualsOne = truth.looselyEquals(oneInt)
    let truthStrictlyEqualsOne = truth.strictlyEquals(oneInt)
    let lieLooselyEqualsZero = lie.looselyEquals(QJSValue(number: 0))
    let nanStrictlyEqualsNan = nan.strictlyEquals(otherNan)
    let nanLooselyEqualsNan = nan.looselyEquals(otherNan)
    let nullLooselyEqualsUndefined = null.looselyEquals(undefined)
    let nullStrictlyEqualsUndefined = null.strictlyEquals(undefined)
    let nullLooselyEqualsZero = null.looselyEquals(QJSValue(number: 0))
    #expect(intStrictlyEqualsDouble)
    #expect(intLooselyEqualsDouble)
    #expect(!intStrictlyEqualsTwo)
    #expect(truthLooselyEqualsOne)
    #expect(!truthStrictlyEqualsOne)
    #expect(lieLooselyEqualsZero)
    #expect(!nanStrictlyEqualsNan)
    #expect(!nanLooselyEqualsNan)
    #expect(nullLooselyEqualsUndefined)
    #expect(!nullStrictlyEqualsUndefined)
    #expect(!nullLooselyEqualsZero)
  }

  @Test
  func immediateValuesWorkInContextOperations() async {
    let virtualMachine = await QJSVirtualMachine(.nonblocking)
    let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

    let key = await context.withInstantContext { scope in
      scope.makePropertyStringKey("constant")
    }

    let handle = await context.withInstantContext { scope -> QJSPersistentHandle in
      let objectResult = scope.makeObject()
      let object: QJSValue
      switch consume objectResult {
      case .value(let value):
        object = scope.persist(value)
      case .exception:
        preconditionFailure("makeObject failed")
      }

      let number = QJSValue(number: 42)
      let wrote = object.setProperty(key, to: number, attributes: .none, in: scope)
      #expect(wrote)

      let readResult = object.getProperty(key, in: scope)
      let read: QJSValue
      switch consume readResult {
      case .value(let value):
        read = value
      case .exception:
        preconditionFailure("getProperty failed")
      }
      let readValue = read.toNumber()
      #expect(readValue == 42)

      let constant = QJSValue(boolean: true)
      return scope.makePersistentHandle(constant)
    }

    let resolved = await context.withInstantContext { scope -> Bool in
      guard let value = scope.resolve(handle) else {
        return false
      }
      return value.toBoolean()
    }
    #expect(resolved)
  }

  @Test
  func classificationOverloadsNeedNoContext() async {
    let virtualMachine = await QJSVirtualMachine(.nonblocking)
    let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

    await context.withInstantContext { scope in
      let arrayResult = scope.makeArray()
      let array: QJSValue
      switch consume arrayResult {
      case .value(let value):
        array = value
      case .exception:
        preconditionFailure("makeArray failed")
      }
      let arrayIsArray = array.isArray()
      let arrayIsBuffer = array.isArrayBuffer()
      let arrayIsTyped = array.isTypedArray()

      let buffer = QJSArrayBuffer(byteLength: 8, in: scope)
      let bufferIsBuffer = buffer.withValue { $0.isArrayBuffer() }
      let bufferIsArray = buffer.withValue { $0.isArray() }

      let typedArray = QJSTypedArray(kind: .uint8Array, length: 4, in: scope)
      let typedIsTyped = typedArray.withValue { $0.isTypedArray() }
      let typedIsBuffer = typedArray.withValue { $0.isArrayBuffer() }

      let number = QJSValue(number: 1)
      let numberIsArray = number.isArray()
      let numberIsBuffer = number.isArrayBuffer()
      let numberIsTyped = number.isTypedArray()

      #expect(arrayIsArray)
      #expect(!arrayIsBuffer)
      #expect(!arrayIsTyped)
      #expect(bufferIsBuffer)
      #expect(!bufferIsArray)
      #expect(typedIsTyped)
      #expect(!typedIsBuffer)
      #expect(!numberIsArray)
      #expect(!numberIsBuffer)
      #expect(!numberIsTyped)
    }
  }

  @Test
  func propertyKeysWorkAcrossContextsOfTheSameRuntime() async {
    let virtualMachine = await QJSVirtualMachine(.nonblocking)
    let first = await QJSContext(virtualMachine: virtualMachine, .nonblocking)
    let second = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

    let key = await first.withInstantContext { scope in
      scope.makePropertyStringKey("shared")
    }

    let value = await second.withInstantContext { scope -> Double in
      let objectResult = scope.makeObject()
      let object: QJSValue
      switch consume objectResult {
      case .value(let value):
        object = scope.persist(value)
      case .exception:
        return .nan
      }

      let number = QJSValue(number: 7)
      _ = object.setProperty(key, to: number, attributes: .none, in: scope)
      let readResult = object.getProperty(key, in: scope)
      switch consume readResult {
      case .value(let value):
        return value.toNumber()
      case .exception:
        return .nan
      }
    }
    #expect(value == 7)
  }

  @Test
  func preparedScriptsWorkAcrossVirtualMachines() async {
    let firstVirtualMachine = await QJSVirtualMachine(.nonblocking)
    let secondVirtualMachine = await QJSVirtualMachine(.nonblocking)
    let first = await QJSContext(virtualMachine: firstVirtualMachine, .nonblocking)
    let second = await QJSContext(virtualMachine: secondVirtualMachine, .nonblocking)

    let prepared = await first.withInstantContext { scope in
      scope.prepareScript("40 + 2")
    }
    let direct = QJSPreparedScript(source: "40 + 2")

    let results = await second.withInstantContext { scope -> (Double, Double) in
      let preparedResult = scope.evaluateScript(
        prepared,
        sourceURL: nil,
        startingLineNumber: 1
      )
      let directResult = scope.evaluateScript(
        direct,
        sourceURL: nil,
        startingLineNumber: 1
      )
      var preparedValue = Double.nan
      switch consume preparedResult {
      case .value(let value):
        preparedValue = value.toNumber()
      case .exception:
        break
      }
      var directValue = Double.nan
      switch consume directResult {
      case .value(let value):
        directValue = value.toNumber()
      case .exception:
        break
      }
      return (preparedValue, directValue)
    }
    #expect(results.0 == 42)
    #expect(results.1 == 42)
  }
}
