import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QJSEngine: JSEngineInvocationDriver {
  public static func callFunctionHandle(
    _ function: QJSValueHandle,
    this thisValue: QJSValueHandle?,
    arguments: [QJSValueHandle],
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    var rawArguments = arguments.map(\.ref)
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

  public static func constructHandle(
    _ constructor: QJSValueHandle,
    arguments: [QJSValueHandle],
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    var rawArguments = arguments.map(\.ref)
    let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
      JS_CallConstructor(context.ref, constructor.ref, Int32(buffer.count), buffer.baseAddress)
    }
    return quickJSResultHandle(for: result, in: context.ref)
  }

  public static func toObjectHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    quickJSResultHandle(for: JS_ToObject(context.ref, value.ref), in: context.ref)
  }

  public static func isArrayHandle(
    _ value: QJSValueHandle,
    in _: QJSContextHandle
  ) -> Bool? {
    JS_IsArray(value.ref)
  }

  public static func isDateHandle(
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

  public static func isInstanceOfHandle(
    _ value: QJSValueHandle,
    constructor: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    let result = JS_IsInstanceOf(context.ref, value.ref, constructor.ref)
    return result >= 0 ? result == 1 : nil
  }

  public static func looselyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    let result = JS_IsEqual(context.ref, lhs.ref, rhs.ref)
    return result >= 0 ? result == 1 : nil
  }

  public static func strictlyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    JS_IsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }
}

// MARK: - Context-side driver conformance (Stage 2B)

extension QJSContextHandle: JSContextInvocationDriver {
  public func callFunctionHandle(
    _ function: QJSValueHandle,
    this thisValue: QJSValueHandle?,
    arguments: [QJSValueHandle]
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.callFunctionHandle(
      function,
      this: thisValue,
      arguments: arguments,
      in: self
    )
  }

  public func constructHandle(
    _ constructor: QJSValueHandle,
    arguments: [QJSValueHandle]
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.constructHandle(constructor, arguments: arguments, in: self)
  }

  public func toObjectHandle(_ value: QJSValueHandle) -> JSResult<QJSValueHandle>? {
    QJSEngine.toObjectHandle(value, in: self)
  }

  public func isArrayHandle(_ value: QJSValueHandle) -> Bool? {
    QJSEngine.isArrayHandle(value, in: self)
  }

  public func isDateHandle(_ value: QJSValueHandle) -> Bool? {
    QJSEngine.isDateHandle(value, in: self)
  }

  public func isInstanceOfHandle(
    _ value: QJSValueHandle,
    constructor: QJSValueHandle
  ) -> Bool? {
    QJSEngine.isInstanceOfHandle(value, constructor: constructor, in: self)
  }

  public func looselyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle
  ) -> Bool? {
    QJSEngine.looselyEqualsHandle(lhs, rhs, in: self)
  }

  public func strictlyEqualsHandle(
    _ lhs: QJSValueHandle,
    _ rhs: QJSValueHandle
  ) -> Bool? {
    QJSEngine.strictlyEqualsHandle(lhs, rhs, in: self)
  }
}
