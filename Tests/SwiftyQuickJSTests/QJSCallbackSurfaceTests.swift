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
// identity structs over `QJSValueHandle`; the arena owns every reference, so
// the views stay valid while the scope below is alive. Return/throw semantics
// belong to S7.

@Suite
struct QJSCallbackSurfaceTests {
  private func makeContext() -> (QJSRuntimeHandle, QJSContextHandle) {
    let runtime = QJSEngine.makeRuntimeHandle()
    guard let context = QJSEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
      preconditionFailure("QJSEngine could not create a context handle")
    }
    return (runtime, context)
  }

  @Test
  func callbackValueExposesConversionsAndEquality() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)

      let text = scope.adoptCreatedHandle(context.makeStringValueHandle("seven")!)
      let twinText = scope.adoptCreatedHandle(context.makeStringValueHandle("seven")!)
      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(7)!)

      let value = QJSCallbackValue(handle: text.borrowHandle(), contextHandle: context)
      let twin = QJSCallbackValue(handle: twinText.borrowHandle(), contextHandle: context)
      let numeric = QJSCallbackValue(handle: number.borrowHandle(), contextHandle: context)

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

      #expect(scope.driverContextHandle == context)
    }
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  @Test
  func callbackArgumentsAccessValuesByIndex() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)
      let text = scope.adoptCreatedHandle(context.makeStringValueHandle("alpha")!)
      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(41)!)
      let handles = [text.borrowHandle(), number.borrowHandle()]

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
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  @Test
  func throwingArgumentAccessPropagatesConversionErrors() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)
      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(3)!)
      let arguments = QJSCallbackArguments(count: 1) { _ in number.borrowHandle() }

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
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }

  @Test
  func argumentsViewDecodesVariadically() {
    let (runtime, context) = makeContext()
    do {
      let scope = QJSInstantContext(handle: context)
      let number = scope.adoptCreatedHandle(context.makeNumberValueHandle(1)!)
      let text = scope.adoptCreatedHandle(context.makeStringValueHandle("two")!)
      let handles = [number.borrowHandle(), text.borrowHandle()]

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
    _ = context.releaseReference()
    _ = runtime.releaseReference()
  }
}
