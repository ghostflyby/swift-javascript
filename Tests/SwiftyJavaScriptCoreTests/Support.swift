import Testing

@testable import SwiftyJavaScriptCore

struct TestNumberMarshal: Sendable, JSValueCodable {
  let value: Double

  init(_ value: Double) {
    self.value = value
  }

  init(value: borrowing JSValue, in context: borrowing JSCallbackContext) {
    self.value = value.isNumber ? 1 : 0
  }

  func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(number: value, in: context)
  }
}

struct TestStringMarshal: Sendable, JSValueCodable, Error {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  init(value: borrowing JSValue, in context: borrowing JSCallbackContext) {
    self.value = value.isString ? "string" : "other"
  }

  func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(string: value, in: context)
  }
}

struct TestBoolMarshal: Sendable, JSValueCodable {
  let value: Bool

  init(_ value: Bool) {
    self.value = value
  }

  init(value: borrowing JSValue, in context: borrowing JSCallbackContext) {
    self.value = value.isBoolean
  }

  func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(boolean: value, in: context)
  }
}
