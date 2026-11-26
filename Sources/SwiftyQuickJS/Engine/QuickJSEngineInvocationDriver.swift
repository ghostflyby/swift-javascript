import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QJSEngine: JSEngineInvocationDriver {
  package static func callFunctionHandle(
    _ function: QJSValueHandle,
    this thisValue: QJSValueHandle?,
    argumentHandles: [QJSValueHandle],
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    var rawArguments = argumentHandles.map(\.ref)
    let thisRawValue = thisValue?.ref ?? quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
    let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
      JS_Call(
        context.ref,
        function.ref,
        thisRawValue,
        Int32(buffer.count),
        buffer.baseAddress
      )
    }
    return quickJSResultHandle(for: result, in: context.ref)
  }

  package static func constructHandle(
    _ constructor: QJSValueHandle,
    argumentHandles: [QJSValueHandle],
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    var rawArguments = argumentHandles.map(\.ref)
    let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
      JS_CallConstructor(context.ref, constructor.ref, Int32(buffer.count), buffer.baseAddress)
    }
    return quickJSResultHandle(for: result, in: context.ref)
  }

  package static func toObjectHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    quickJSResultHandle(for: JS_ToObject(context.ref, value.ref), in: context.ref)
  }

  package static func isArrayHandle(
    _ value: QJSValueHandle,
    in _: QJSContextHandle
  ) -> Bool? {
    JS_IsArray(value.ref)
  }

  package static func isDateHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    guard JS_IsObject(value.ref) else {
      return false
    }
    let globalObject = JS_GetGlobalObject(context.ref)
    defer { JS_FreeValue(context.ref, globalObject) }
    let dateConstructor = JS_GetPropertyStr(context.ref, globalObject, "Date")
    defer { JS_FreeValue(context.ref, dateConstructor) }
    if JS_IsException(dateConstructor) {
      return nil
    }
    let result = JS_IsInstanceOf(context.ref, value.ref, dateConstructor)
    return result >= 0 ? result == 1 : nil
  }

  package static func isInstanceOfHandle(
    _ value: QJSValueHandle,
    constructor: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    let result = JS_IsInstanceOf(context.ref, value.ref, constructor.ref)
    return result >= 0 ? result == 1 : nil
  }

  package static func looselyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    let result = JS_IsEqual(context.ref, lhs.ref, rhs.ref)
    return result >= 0 ? result == 1 : nil
  }

  package static func strictlyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    JS_IsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }
}

// MARK: - Context-side driver conformance (Stage 2B)

extension QJSContextHandle: JSContextInvocationDriver {
  package func callFunctionHandle(
    _ function: QJSValueHandle,
    this thisValue: QJSValueHandle?,
    argumentHandles: [QJSValueHandle]
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.callFunctionHandle(
      function,
      this: thisValue,
      argumentHandles: argumentHandles,
      in: self
    )
  }

  package func constructHandle(
    _ constructor: QJSValueHandle,
    argumentHandles: [QJSValueHandle]
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.constructHandle(constructor, argumentHandles: argumentHandles, in: self)
  }

  package func toObjectHandle(_ value: QJSValueHandle) -> JSResult<QJSValueHandle>? {
    QJSEngine.toObjectHandle(value, in: self)
  }

  package func isArrayHandle(_ value: QJSValueHandle) -> Bool? {
    QJSEngine.isArrayHandle(value, in: self)
  }

  package func isDateHandle(_ value: QJSValueHandle) -> Bool? {
    QJSEngine.isDateHandle(value, in: self)
  }

  package func isInstanceOfHandle(
    _ value: QJSValueHandle,
    constructor: QJSValueHandle
  ) -> Bool? {
    QJSEngine.isInstanceOfHandle(value, constructor: constructor, in: self)
  }

  package func looselyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle
  ) -> Bool? {
    QJSEngine.looselyEqualsHandle(lhs, rhs, in: self)
  }

  package func strictlyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle
  ) -> Bool? {
    QJSEngine.strictlyEqualsHandle(lhs, rhs, in: self)
  }
}
