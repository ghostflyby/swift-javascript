import JavaScriptCore
import SwiftJavaScript

extension JSCEngine: JSEngineInvocationDriver {
  public static func callFunctionHandle(
    _ function: JSValueHandle<JSCEngine>,
    this thisValue: JSValueHandle<JSCEngine>? = nil,
    arguments: [JSValueHandle<JSCEngine>] = [],
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    callFunction(function, this: thisValue, arguments: arguments, in: context)
  }

  public static func constructHandle(
    _ constructor: JSValueHandle<JSCEngine>,
    arguments: [JSValueHandle<JSCEngine>] = [],
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    construct(constructor, arguments: arguments, in: context)
  }

  public static func toObjectHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    toObject(value, in: context)
  }

  public static func isArrayHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsArray(context.ref, value.ref)
  }

  public static func isDateHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsDate(context.ref, value.ref)
  }

  public static func isInstanceOfHandle(
    _ value: JSValueHandle<JSCEngine>,
    constructor: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    isInstanceOf(value, constructor: constructor, in: context)
  }

  public static func looselyEqualsHandle(
    _ lhs: JSValueHandle<JSCEngine>,
    _ rhs: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsEqual(context.ref, lhs.ref, rhs.ref, nil)
  }

  public static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<JSCEngine>,
    _ rhs: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }

  private static func callFunction(
    _ function: JSCValueHandle,
    this thisValue: JSCValueHandle?,
    arguments: [JSCValueHandle],
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
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
    _ constructor: JSCValueHandle,
    arguments: [JSCValueHandle],
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
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
    _ value: JSCValueHandle,
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return .value(JSCValueHandle(ref: objectRef))
    }
  }

  private static func isInstanceOf(
    _ value: JSCValueHandle,
    constructor: JSCValueHandle,
    in context: JSCContextHandle
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

extension JSCContextHandle: JSContextInvocationDriver {
  public func callFunctionHandle(
    _ function: JSCValueHandle,
    this thisValue: JSCValueHandle?,
    arguments: [JSCValueHandle]
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.callFunctionHandle(
      function,
      this: thisValue,
      arguments: arguments,
      in: self
    )
  }

  public func constructHandle(
    _ constructor: JSCValueHandle,
    arguments: [JSCValueHandle]
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.constructHandle(constructor, arguments: arguments, in: self)
  }

  public func toObjectHandle(_ value: JSCValueHandle)
    -> JSResult<JSCValueHandle>?
  {
    JSCEngine.toObjectHandle(value, in: self)
  }

  public func isArrayHandle(_ value: JSCValueHandle) -> Bool? {
    JSCEngine.isArrayHandle(value, in: self)
  }

  public func isDateHandle(_ value: JSCValueHandle) -> Bool? {
    JSCEngine.isDateHandle(value, in: self)
  }

  public func isInstanceOfHandle(
    _ value: JSCValueHandle,
    constructor: JSCValueHandle
  ) -> Bool? {
    JSCEngine.isInstanceOfHandle(value, constructor: constructor, in: self)
  }

  public func looselyEqualsHandle(
    _ lhs: JSCValueHandle,
    _ rhs: JSCValueHandle
  ) -> Bool? {
    JSCEngine.looselyEqualsHandle(lhs, rhs, in: self)
  }

  public func strictlyEqualsHandle(
    _ lhs: JSCValueHandle,
    _ rhs: JSCValueHandle
  ) -> Bool? {
    JSCEngine.strictlyEqualsHandle(lhs, rhs, in: self)
  }
}
