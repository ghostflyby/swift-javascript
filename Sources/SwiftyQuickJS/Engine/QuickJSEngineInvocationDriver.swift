import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QuickJSEngine: JSEngineInvocationDriver {
  @_lifetime(immortal)
  public static func callFunctionHandle(
    _ function: QuickJSValueHandle,
    this thisValue: QuickJSValueHandle?,
    arguments: [QuickJSValueHandle],
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
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

  @_lifetime(immortal)
  public static func constructHandle(
    _ constructor: QuickJSValueHandle,
    arguments: [QuickJSValueHandle],
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    var rawArguments = arguments.map(\.ref)
    let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
      JS_CallConstructor(context.ref, constructor.ref, Int32(buffer.count), buffer.baseAddress)
    }
    return quickJSResultHandle(for: result, in: context.ref)
  }

  @_lifetime(immortal)
  public static func toObjectHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    quickJSResultHandle(for: JS_ToObject(context.ref, value.ref), in: context.ref)
  }

  public static func isArrayHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> Bool? {
    JS_IsArray(value.ref)
  }

  public static func isDateHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
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
    _ value: QuickJSValueHandle,
    constructor: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let result = JS_IsInstanceOf(context.ref, value.ref, constructor.ref)
    return result >= 0 ? result == 1 : nil
  }

  public static func looselyEqualsHandle(
    _ lhs: QuickJSValueHandle,
    _ rhs: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let result = JS_IsEqual(context.ref, lhs.ref, rhs.ref)
    return result >= 0 ? result == 1 : nil
  }

  public static func strictlyEqualsHandle(
    _ lhs: QuickJSValueHandle,
    _ rhs: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    JS_IsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }
}
