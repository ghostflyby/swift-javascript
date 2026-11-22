import JavaScriptCore
import SwiftJavaScript

extension JavaScriptCoreEngine: JSEngineInvocationDriver {
  public static func callFunctionHandle(
    _ function: JSValueHandle<JavaScriptCoreEngine>,
    this thisValue: JSValueHandle<JavaScriptCoreEngine>? = nil,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = [],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    callFunction(function, this: thisValue, arguments: arguments, in: context)
  }

  public static func constructHandle(
    _ constructor: JSValueHandle<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = [],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    construct(constructor, arguments: arguments, in: context)
  }

  public static func toObjectHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    toObject(value, in: context)
  }

  public static func isArrayHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    JSValueIsArray(context.ref, value.ref)
  }

  public static func isDateHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    JSValueIsDate(context.ref, value.ref)
  }

  public static func isInstanceOfHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    constructor: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    isInstanceOf(value, constructor: constructor, in: context)
  }

  public static func looselyEqualsHandle(
    _ lhs: JSValueHandle<JavaScriptCoreEngine>,
    _ rhs: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    JSValueIsEqual(context.ref, lhs.ref, rhs.ref, nil)
  }

  public static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<JavaScriptCoreEngine>,
    _ rhs: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    JSValueIsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }

  private static func callFunction(
    _ function: JavaScriptCoreValueHandle,
    this thisValue: JavaScriptCoreValueHandle?,
    arguments: [JavaScriptCoreValueHandle],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: function, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let functionRef):
      let thisObjectRef: JSObjectRef?
      if let thisValue {
        switch javaScriptCoreObjectRef(for: thisValue, in: context) {
        case .exception(let exception):
          return .exception(exception)
        case .object(let objectRef):
          thisObjectRef = objectRef
        }
      } else {
        thisObjectRef = nil
      }

      var exception: JSValueRef?
      let refs = arguments.map { Optional($0.ref) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsFunction(
          context.ref,
          functionRef,
          thisObjectRef,
          buffer.count,
          buffer.baseAddress,
          &exception
        )
      }
      return javaScriptCoreResult(value: resultRef, exception: exception, in: context)
    }
  }

  private static func construct(
    _ constructor: JavaScriptCoreValueHandle,
    arguments: [JavaScriptCoreValueHandle],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: constructor, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let constructorRef):
      var exception: JSValueRef?
      let refs = arguments.map { Optional($0.ref) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsConstructor(
          context.ref,
          constructorRef,
          buffer.count,
          buffer.baseAddress,
          &exception
        )
      }
      return javaScriptCoreResult(value: resultRef, exception: exception, in: context)
    }
  }

  private static func toObject(
    _ value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return .value(JavaScriptCoreValueHandle(ref: objectRef))
    }
  }

  private static func isInstanceOf(
    _ value: JavaScriptCoreValueHandle,
    constructor: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch javaScriptCoreObjectRef(for: constructor, in: context) {
    case .exception:
      return false
    case .object(let constructorRef):
      var exception: JSValueRef?
      let result = JSValueIsInstanceOfConstructor(
        context.ref,
        value.ref,
        constructorRef,
        &exception
      )
      return exception == nil && result
    }
  }
}

// MARK: - Context-side driver conformance (Stage 2B)

extension JavaScriptCoreContextHandle: JSContextInvocationDriver {
  public func callFunctionHandle(
    _ function: JavaScriptCoreValueHandle,
    this thisValue: JavaScriptCoreValueHandle?,
    arguments: [JavaScriptCoreValueHandle]
  ) -> JSResult<JavaScriptCoreValueHandle>? {
    JavaScriptCoreEngine.callFunctionHandle(
      function,
      this: thisValue,
      arguments: arguments,
      in: self
    )
  }

  public func constructHandle(
    _ constructor: JavaScriptCoreValueHandle,
    arguments: [JavaScriptCoreValueHandle]
  ) -> JSResult<JavaScriptCoreValueHandle>? {
    JavaScriptCoreEngine.constructHandle(constructor, arguments: arguments, in: self)
  }

  public func toObjectHandle(_ value: JavaScriptCoreValueHandle)
    -> JSResult<JavaScriptCoreValueHandle>?
  {
    JavaScriptCoreEngine.toObjectHandle(value, in: self)
  }

  public func isArrayHandle(_ value: JavaScriptCoreValueHandle) -> Bool? {
    JavaScriptCoreEngine.isArrayHandle(value, in: self)
  }

  public func isDateHandle(_ value: JavaScriptCoreValueHandle) -> Bool? {
    JavaScriptCoreEngine.isDateHandle(value, in: self)
  }

  public func isInstanceOfHandle(
    _ value: JavaScriptCoreValueHandle,
    constructor: JavaScriptCoreValueHandle
  ) -> Bool? {
    JavaScriptCoreEngine.isInstanceOfHandle(value, constructor: constructor, in: self)
  }

  public func looselyEqualsHandle(
    _ lhs: JavaScriptCoreValueHandle,
    _ rhs: JavaScriptCoreValueHandle
  ) -> Bool? {
    JavaScriptCoreEngine.looselyEqualsHandle(lhs, rhs, in: self)
  }

  public func strictlyEqualsHandle(
    _ lhs: JavaScriptCoreValueHandle,
    _ rhs: JavaScriptCoreValueHandle
  ) -> Bool? {
    JavaScriptCoreEngine.strictlyEqualsHandle(lhs, rhs, in: self)
  }
}
