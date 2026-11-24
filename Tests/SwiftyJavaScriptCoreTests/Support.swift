import Testing

@testable import SwiftyJavaScriptCore

struct TestNumberMarshal: Sendable, JSValueDecodable, JSValueEncodable {
  let value: Double

  init(_ value: Double) {
    self.value = value
  }

  init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self.value = value.isNumber() ? 1 : 0
  }

  func toSurfaceValue<C: JSValueScope & ~Copyable>(in context: borrowing C) -> C.Value {
    context.persist(context.makeNumber(value))
  }
}

struct TestStringMarshal: Sendable, JSValueDecodable, JSValueEncodable, Error {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self.value = value.isString() ? "string" : "other"
  }

  func toSurfaceValue<C: JSValueScope & ~Copyable>(in context: borrowing C) -> C.Value {
    context.persist(context.makeString(value))
  }
}

struct TestBoolMarshal: Sendable, JSValueDecodable, JSValueEncodable {
  let value: Bool

  init(_ value: Bool) {
    self.value = value
  }

  init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self.value = value.isBoolean()
  }

  func toSurfaceValue<C: JSValueScope & ~Copyable>(in context: borrowing C) -> C.Value {
    context.persist(context.makeBoolean(value))
  }
}
