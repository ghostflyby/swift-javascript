import JavaScriptCore
import SwiftJavaScript

package func javaScriptCoreCallFunctionHandle(
  _ function: JSValueRef,
  this thisValue: JSValueRef? = nil,
  argumentHandles: [JSValueRef] = [],
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  javaScriptCoreCallFunction(
    function, this: thisValue, argumentHandles: argumentHandles, in: context)
}

package func javaScriptCoreConstructHandle(
  _ constructor: JSValueRef,
  argumentHandles: [JSValueRef] = [],
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  javaScriptCoreConstruct(constructor, argumentHandles: argumentHandles, in: context)
}

package func javaScriptCoreToObjectHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  javaScriptCoreToObject(value, in: context)
}

package func javaScriptCoreIsArrayHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  JSValueIsArray(context, value)
}

package func javaScriptCoreIsDateHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  JSValueIsDate(context, value)
}

package func javaScriptCoreIsInstanceOfHandle(
  _ value: JSValueRef,
  constructor: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  javaScriptCoreIsInstanceOf(value, constructor: constructor, in: context)
}

package func javaScriptCoreLooselyEqualsHandle(
  _ lhs: JSValueRef,
  _ rhs: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  JSValueIsEqual(context, lhs, rhs, nil)
}

package func javaScriptCoreStrictlyEqualsHandle(
  _ lhs: JSValueRef,
  _ rhs: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  JSValueIsStrictEqual(context, lhs, rhs)
}

private func javaScriptCoreCallFunction(
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

private func javaScriptCoreConstruct(
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

private func javaScriptCoreToObject(
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

private func javaScriptCoreIsInstanceOf(
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

// MARK: - Context-side driver conformance (Stage 2B)
