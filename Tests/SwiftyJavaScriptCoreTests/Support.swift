import Testing

@testable import SwiftyJavaScriptCore

extension JSContext {
  func withIsolatedGlobalObject<R: Sendable>(
    _ body: @Sendable (isolated JSContext, borrowing JSValue) -> R
  ) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(self, globalObject)
  }
}

struct TestNumberMarshal: Sendable, JSValueMarshal {
  let value: Double

  init(_ value: Double) {
    self.value = value
  }

  init(value: borrowing JSValue, in context: isolated JSContext) {
    self.value = value.isNumber ? 1 : 0
  }

  func toJSValue(in context: isolated JSContext) -> JSValue {
    JSValue(number: value, in: context)
  }
}

struct TestStringMarshal: Sendable, JSValueMarshal, Error {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  init(value: borrowing JSValue, in context: isolated JSContext) {
    self.value = value.isString ? "string" : "other"
  }

  func toJSValue(in context: isolated JSContext) -> JSValue {
    JSValue(string: value, in: context)
  }
}

struct TestBoolMarshal: Sendable, JSValueMarshal {
  let value: Bool

  init(_ value: Bool) {
    self.value = value
  }

  init(value: borrowing JSValue, in context: isolated JSContext) {
    self.value = value.isBoolean
  }

  func toJSValue(in context: isolated JSContext) -> JSValue {
    JSValue(boolean: value, in: context)
  }
}
