import SwiftyJavaScriptCore

package struct TestNumberMarshal: Sendable, JSValueCodable {
  package let value: Double

  package init(_ value: Double) {
    self.value = value
  }

  package init<E: JSEngine>(
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

  package init(
    value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.value = value.isNumber(in: context) ? 1 : 0
  }

  @_lifetime(borrow context)
  package func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(number: value, in: context)
  }

  @_lifetime(borrow context)
  package func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(number: value, in: jscContext).takeHandle()
    }
  }
}

package struct TestStringMarshal: Sendable, JSValueCodable, Error {
  package let value: String

  package init(_ value: String) {
    self.value = value
  }

  package init<E: JSEngine>(
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

  package init(
    value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.value = value.isString(in: context) ? "string" : "other"
  }

  @_lifetime(borrow context)
  package func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(string: value, in: context)
  }

  @_lifetime(borrow context)
  package func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(string: value, in: jscContext).takeHandle()
    }
  }
}

package struct TestBoolMarshal: Sendable, JSValueCodable {
  package let value: Bool

  package init(_ value: Bool) {
    self.value = value
  }

  package init<E: JSEngine>(
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

  package init(
    value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) {
    self.value = value.isBoolean(in: context)
  }

  @_lifetime(borrow context)
  package func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(boolean: value, in: context)
  }

  @_lifetime(borrow context)
  package func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(boolean: value, in: jscContext).takeHandle()
    }
  }
}
