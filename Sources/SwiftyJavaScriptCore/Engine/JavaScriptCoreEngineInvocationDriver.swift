import JavaScriptCore
import SwiftJavaScript

extension JSCEngine: JSEngineInvocationDriver {
  package static func callFunctionHandle(
    _ function: JSValueHandle<JSCEngine>,
    this thisValue: JSValueHandle<JSCEngine>? = nil,
    argumentHandles: [JSValueHandle<JSCEngine>] = [],
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    callFunction(function, this: thisValue, argumentHandles: argumentHandles, in: context)
  }

  package static func constructHandle(
    _ constructor: JSValueHandle<JSCEngine>,
    argumentHandles: [JSValueHandle<JSCEngine>] = [],
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    construct(constructor, argumentHandles: argumentHandles, in: context)
  }

  package static func toObjectHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    toObject(value, in: context)
  }

  package static func isArrayHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsArray(context.ref, value.ref)
  }

  package static func isDateHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsDate(context.ref, value.ref)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueHandle<JSCEngine>,
    constructor: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    isInstanceOf(value, constructor: constructor, in: context)
  }

  package static func looselyEqualsHandle(
    _ lhs: JSValueHandle<JSCEngine>,
    _ rhs: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsEqual(context.ref, lhs.ref, rhs.ref, nil)
  }

  package static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<JSCEngine>,
    _ rhs: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    JSValueIsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }

  private static func callFunction(
    _ function: JSCValueHandle,
    this thisValue: JSCValueHandle?,
    argumentHandles: [JSCValueHandle],
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
      let refs = argumentHandles.map { Optional($0.ref) }
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
    argumentHandles: [JSCValueHandle],
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
    switch javaScriptCoreObjectRef(for: constructor, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let constructorRef):
      var exception: JSValueRef?
      let refs = argumentHandles.map { Optional($0.ref) }
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
  package func callFunctionHandle(
    _ function: JSCValueHandle,
    this thisValue: JSCValueHandle?,
    argumentHandles: [JSCValueHandle]
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.callFunctionHandle(
      function,
      this: thisValue,
      argumentHandles: argumentHandles,
      in: self
    )
  }

  package func constructHandle(
    _ constructor: JSCValueHandle,
    argumentHandles: [JSCValueHandle]
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.constructHandle(constructor, argumentHandles: argumentHandles, in: self)
  }

  package func toObjectHandle(_ value: JSCValueHandle)
    -> JSResult<JSCValueHandle>?
  {
    JSCEngine.toObjectHandle(value, in: self)
  }

  package func isArrayHandle(_ value: JSCValueHandle) -> Bool? {
    JSCEngine.isArrayHandle(value, in: self)
  }

  package func isDateHandle(_ value: JSCValueHandle) -> Bool? {
    JSCEngine.isDateHandle(value, in: self)
  }

  package func isInstanceOfHandle(
    _ value: JSCValueHandle,
    constructor: JSCValueHandle
  ) -> Bool? {
    JSCEngine.isInstanceOfHandle(value, constructor: constructor, in: self)
  }

  package func looselyEqualsHandle(
    _ lhs: JSCValueHandle,
    _ rhs: JSCValueHandle
  ) -> Bool? {
    JSCEngine.looselyEqualsHandle(lhs, rhs, in: self)
  }

  package func strictlyEqualsHandle(
    _ lhs: JSCValueHandle,
    _ rhs: JSCValueHandle
  ) -> Bool? {
    JSCEngine.strictlyEqualsHandle(lhs, rhs, in: self)
  }
}
