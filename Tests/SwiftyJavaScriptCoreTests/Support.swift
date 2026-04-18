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
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    self.init(
      value: JSValue<JavaScriptCoreEngine>(
        handleValue: unsafeBitCast(
          value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
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
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    let encoded = self.toJSValue(
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
    return JSValue<E>(handleValue: unsafeBitCast(encoded.takeHandle(), to: JSValueHandle<E>.self))
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
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    self.init(
      value: JSValue<JavaScriptCoreEngine>(
        handleValue: unsafeBitCast(
          value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
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
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    let encoded = self.toJSValue(
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
    return JSValue<E>(handleValue: unsafeBitCast(encoded.takeHandle(), to: JSValueHandle<E>.self))
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
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    self.init(
      value: JSValue<JavaScriptCoreEngine>(
        handleValue: unsafeBitCast(
          value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
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
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    let encoded = self.toJSValue(
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
    return JSValue<E>(handleValue: unsafeBitCast(encoded.takeHandle(), to: JSValueHandle<E>.self))
  }
}
