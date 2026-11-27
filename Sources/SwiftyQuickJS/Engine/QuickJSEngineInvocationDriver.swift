import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

package func quickJSCallFunction(
  _ function: CQuickJSValue,
  this thisValue: CQuickJSValue? = nil,
  arguments: [CQuickJSValue] = [],
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  var rawArguments = arguments
  let thisRawValue = thisValue ?? quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
    JS_Call(
      context,
      function,
      thisRawValue,
      Int32(buffer.count),
      buffer.baseAddress
    )
  }
  return quickJSResult(for: result, in: context)
}

package func quickJSConstruct(
  _ constructor: CQuickJSValue,
  arguments: [CQuickJSValue] = [],
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  var rawArguments = arguments
  let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
    JS_CallConstructor(context, constructor, Int32(buffer.count), buffer.baseAddress)
  }
  return quickJSResult(for: result, in: context)
}

package func quickJSToObject(
  _ value: CQuickJSValue,
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  return quickJSResult(for: JS_ToObject(context, value), in: context)
}

package func quickJSIsArray(
  _ value: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  _ = context
  return JS_IsArray(value)
}

package func quickJSIsDate(
  _ value: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  guard JS_IsObject(value) else {
    return false
  }
  let globalObject = JS_GetGlobalObject(context)
  defer { JS_FreeValue(context, globalObject) }
  let dateConstructor = JS_GetPropertyStr(context, globalObject, "Date")
  defer { JS_FreeValue(context, dateConstructor) }
  if JS_IsException(dateConstructor) {
    return nil
  }
  let result = JS_IsInstanceOf(context, value, dateConstructor)
  return result >= 0 ? result == 1 : nil
}

package func quickJSIsInstanceOf(
  _ value: CQuickJSValue,
  constructor: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  let result = JS_IsInstanceOf(context, value, constructor)
  return result >= 0 ? result == 1 : nil
}

package func quickJSLooselyEquals(
  _ lhs: CQuickJSValue,
  _ rhs: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  let result = JS_IsEqual(context, lhs, rhs)
  return result >= 0 ? result == 1 : nil
}

package func quickJSStrictlyEquals(
  _ lhs: CQuickJSValue,
  _ rhs: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  return JS_IsStrictEqual(context, lhs, rhs)
}
