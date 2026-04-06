import Testing

@testable import SwiftyJavaScriptCore

struct TestNumberMarshal: Sendable, JSValueCodable {
  let value: Double

  init(_ value: Double) {
    self.value = value
  }

  init<E: JSEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self.init(
      value: _bridgeJavaScriptCoreValue(value),
      in: _bridgeJavaScriptCoreContext(context)
    )
  }

  init(
    value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.value = value.isNumber(in: context) ? 1 : 0
  }

  func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(number: value, in: context)
  }

  func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    _asGenericValue(self.toJSValue(in: _bridgeJavaScriptCoreContext(context)))
  }
}

struct TestStringMarshal: Sendable, JSValueCodable, Error {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  init<E: JSEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self.init(
      value: _bridgeJavaScriptCoreValue(value),
      in: _bridgeJavaScriptCoreContext(context)
    )
  }

  init(
    value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.value = value.isString(in: context) ? "string" : "other"
  }

  func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(string: value, in: context)
  }

  func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    _asGenericValue(self.toJSValue(in: _bridgeJavaScriptCoreContext(context)))
  }
}

struct TestBoolMarshal: Sendable, JSValueCodable {
  let value: Bool

  init(_ value: Bool) {
    self.value = value
  }

  init<E: JSEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self.init(
      value: _bridgeJavaScriptCoreValue(value),
      in: _bridgeJavaScriptCoreContext(context)
    )
  }

  init(
    value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.value = value.isBoolean(in: context)
  }

  func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(boolean: value, in: context)
  }

  func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    _asGenericValue(self.toJSValue(in: _bridgeJavaScriptCoreContext(context)))
  }
}
