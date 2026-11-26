import JavaScriptCore
import SwiftJavaScript

extension JSCEngine {
  package static func callFunctionHandle(
    _ function: JSValueRef,
    this thisValue: JSValueRef? = nil,
    argumentHandles: [JSValueRef] = [],
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    callFunction(function, this: thisValue, argumentHandles: argumentHandles, in: context)
  }

  package static func constructHandle(
    _ constructor: JSValueRef,
    argumentHandles: [JSValueRef] = [],
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    construct(constructor, argumentHandles: argumentHandles, in: context)
  }

  package static func toObjectHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    toObject(value, in: context)
  }

  package static func isArrayHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    JSValueIsArray(context, value)
  }

  package static func isDateHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    JSValueIsDate(context, value)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueRef,
    constructor: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    isInstanceOf(value, constructor: constructor, in: context)
  }

  package static func looselyEqualsHandle(
    _ lhs: JSValueRef,
    _ rhs: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    JSValueIsEqual(context, lhs, rhs, nil)
  }

  package static func strictlyEqualsHandle(
    _ lhs: JSValueRef,
    _ rhs: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    JSValueIsStrictEqual(context, lhs, rhs)
  }

  private static func callFunction(
    _ function: JSValueRef,
    this thisValue: JSValueRef?,
    argumentHandles: [JSValueRef],
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef> {
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
      let refs = argumentHandles.map { Optional($0) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsFunction(
          context,
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
    _ constructor: JSValueRef,
    argumentHandles: [JSValueRef],
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef> {
    switch javaScriptCoreObjectRef(for: constructor, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let constructorRef):
      var exception: JSValueRef?
      let refs = argumentHandles.map { Optional($0) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsConstructor(
          context,
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
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef> {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return .value(objectRef)
    }
  }

  private static func isInstanceOf(
    _ value: JSValueRef,
    constructor: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    switch javaScriptCoreObjectRef(for: constructor, in: context) {
    case .exception:
      return false
    case .object(let constructorRef):
      var exception: JSValueRef?
      let result = JSValueIsInstanceOfConstructor(
        context,
        value,
        constructorRef,
        &exception
      )
      return exception == nil && result
    }
  }
}

// MARK: - Context-side driver conformance (Stage 2B)
