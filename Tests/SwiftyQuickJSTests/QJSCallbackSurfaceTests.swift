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

// MARK: - Surface callback views (S6), QuickJS
//
// Mirror of `JSCCallbackSurfaceTests`: the callback-window views are concrete
// identity structs over `CQuickJSValue`; the arena owns every reference, so
// the views stay valid while the scope below is alive. Return/throw semantics
// belong to S7.

@Suite
struct QJSCallbackSurfaceTests {
  private func makeContext() -> (OpaquePointer, OpaquePointer) {
    let runtime = quickJSMakeRuntime()
    guard let context = JS_NewContext(runtime) else {
      preconditionFailure("QuickJS could not create a context")
    }
    return (runtime, context)
  }

  @Test
  func callbackValueExposesConversionsAndEquality() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(contextRef: context)

      let text = scope.adoptCreated(quickJSMakeString("seven", in: context)!)
      let twinText = scope.adoptCreated(quickJSMakeString("seven", in: context)!)
      let number = scope.adoptCreated(quickJSMakeNumber(7, in: context)!)

      let value = QJSValue(value: text.value, contextRef: context)
      let twin = QJSValue(value: twinText.value, contextRef: context)
      let numeric = QJSValue(value: number.value, contextRef: context)

      let valueType = value.type()
      let valueText = value.toString()
      let valueNumber = value.toNumber()
      let valueTruth = value.toBoolean()
      let numberType = numeric.type()
      let isString = value.isString()
      let numberIsNumber = numeric.isNumber()
      let looselyMatchesTwin = value.looselyEquals(twin)
      let strictlyMatchesTwin = value.strictlyEquals(twin)
      let strictlyMatchesNumber = value.strictlyEquals(numeric)

      #expect(valueType == .string)
      #expect(valueText == "seven")
      #expect(valueNumber.isNaN)
      #expect(valueTruth)
      #expect(numberType == .number)
      #expect(isString)
      #expect(numberIsNumber)
      #expect(looselyMatchesTwin)
      #expect(strictlyMatchesTwin)
      #expect(!strictlyMatchesNumber)

      #expect(scope.contextRef == context)
    }
    JS_FreeContext(context)
    JS_FreeRuntime(runtime)
  }

  @Test
  func callbackArgumentsAccessValuesByIndex() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(contextRef: context)
      let text = scope.adoptCreated(quickJSMakeString("alpha", in: context)!)
      let number = scope.adoptCreated(quickJSMakeNumber(41, in: context)!)
      let handles = [text.value, number.value]

      let arguments = QJSCallbackArguments(count: handles.count) { index in
        index >= 0 && index < handles.count ? handles[index] : nil
      }

      let count = arguments.count
      let firstType = arguments.withValue(at: 0, in: scope) { $0.type() }
      let secondText = arguments.withValue(at: 1, in: scope) { $0.toString() }
      let throwingResult: String = try! arguments.withThrowingValue(at: 0, in: scope) {
        value throws(JSValueConversionError) in
        guard value.type() == .string else {
          throw JSValueConversionError.typeMismatch(expected: "string", actual: value.type())
        }
        return value.toString()
      }

      #expect(count == 2)
      #expect(firstType == .string)
      #expect(secondText == "41")
      #expect(throwingResult == "alpha")
    }
    JS_FreeContext(context)
    JS_FreeRuntime(runtime)
  }

  @Test
  func throwingArgumentAccessPropagatesConversionErrors() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(contextRef: context)
      let number = scope.adoptCreated(quickJSMakeNumber(3, in: context)!)
      let arguments = QJSCallbackArguments(count: 1) { _ in number.value }

      do {
        let _: String = try arguments.withThrowingValue(at: 0, in: scope) {
          value throws(JSValueConversionError) in
          guard value.isString() else {
            throw JSValueConversionError.typeMismatch(
              expected: "string", actual: value.type())
          }
          return value.toString()
        }
        Issue.record("Expected strict argument access to fail")
      } catch let error as JSValueConversionError {
        guard case .typeMismatch(let expected, _) = error else {
          Issue.record("Expected a typeMismatch error")
          return
        }
        #expect(expected == "string")
      }
    }
    JS_FreeContext(context)
    JS_FreeRuntime(runtime)
  }

  @Test
  func argumentsViewDecodesVariadically() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(contextRef: context)
      let number = scope.adoptCreated(quickJSMakeNumber(1, in: context)!)
      let text = scope.adoptCreated(quickJSMakeString("two", in: context)!)
      let handles = [number.value, text.value]

      let arguments = QJSArguments(count: handles.count) { index, _ in
        index >= 0 && index < handles.count ? handles[index] : nil
      }

      let unpacked = arguments.unpack(types: Double.self, String.self, in: scope)
      let strict = try! arguments.tryUnpack(types: Double.self, String.self, in: scope)

      #expect(unpacked.0 == 1)
      #expect(unpacked.1 == "two")
      #expect(strict.0 == 1)
      #expect(strict.1 == "two")
    }
    JS_FreeContext(context)
    JS_FreeRuntime(runtime)
  }
}
