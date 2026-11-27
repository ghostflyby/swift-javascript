import JavaScriptCore
import Testing

@testable import SwiftJavaScript
@testable import SwiftyJavaScriptCore

// MARK: - Surface callback views (S6)
//
// `JSCValue`/`JSCCallbackArguments` are the concrete callback-window
// views handed to `JSFunctionCallback<JSCEngine>`. These tests construct them
// directly from arena-backed handles and exercise classification/conversion,
// equality, and indexed argument access. Callback return/throw semantics belong
// to the S7 scope slice.

@Suite
struct JSCCallbackSurfaceTests {
  private func makeContext() -> (JSContextGroupRef, JSGlobalContextRef) {
    let runtime = JSContextGroupCreate()!
    guard let context = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
      preconditionFailure("JSCEngine could not create a context handle")
    }
    return (runtime, context)
  }

  @Test
  func callbackValueExposesConversionsAndEquality() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)

      let text = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("seven", context)!)
      let twinText = scope.adoptCreatedHandle(
        javaScriptCoreMakeStringValueHandle("seven", context)!)
      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(7, context)!)

      let value = JSCValue(ref: text.ref, contextRef: context)
      let twin = JSCValue(ref: twinText.ref, contextRef: context)
      let numeric = JSCValue(ref: number.ref, contextRef: context)

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
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func callbackArgumentsAccessValuesByIndex() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let text = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("alpha", context)!)
      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(41, context)!)
      let handles = [text.ref, number.ref]

      let arguments = JSCCallbackArguments(count: handles.count) { index in
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
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func throwingArgumentAccessPropagatesConversionErrors() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(3, context)!)
      let arguments = JSCCallbackArguments(count: 1) { _ in number.ref }

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
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func argumentsViewDecodesVariadically() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(1, context)!)
      let text = scope.adoptCreatedHandle(javaScriptCoreMakeStringValueHandle("two", context)!)
      let handles = [number.ref, text.ref]

      let arguments = JSCArguments(count: handles.count) { index, _ in
        index >= 0 && index < handles.count ? handles[index] : nil
      }

      let unpacked = arguments.unpack(types: Double.self, String.self, in: scope)
      let strict = try! arguments.tryUnpack(types: Double.self, String.self, in: scope)
      let converted = arguments.unpack(
        using: SurfaceDoubledNumber.self, SurfaceUppercasedString.self, in: scope)
      let strictlyConverted = try! arguments.tryUnpack(
        using: SurfaceDoubledNumber.self, SurfaceUppercasedString.self, in: scope)

      #expect(unpacked.0 == 1)
      #expect(unpacked.1 == "two")
      #expect(strict.0 == 1)
      #expect(strict.1 == "two")
      #expect(converted.0 == 2)
      #expect(converted.1 == "TWO")
      #expect(strictlyConverted.0 == 2)
      #expect(strictlyConverted.1 == "TWO")
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }
}

// MARK: - Test converters for the surface argument defaults

private struct SurfaceDoubledNumber: JSValueDecoder {
  typealias SwiftType = Double

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Double {
    value.toNumber() * 2
  }
}

private struct SurfaceUppercasedString: JSValueDecoder {
  typealias SwiftType = String

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> String {
    value.toString().uppercased()
  }
}
