import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
  package typealias CQuickJSValue = CQuickJSStatic.JSValue
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
  package typealias CQuickJSValue = CQuickJSDynamic.JSValue
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
  package typealias CQuickJSValue = CQuickJSSystem.JSValue
#endif

/// Map one engine result to the core `JSResult`: an exception engine value is
/// replaced by the pending exception it carries.
@_lifetime(borrow contextRef)
func quickJSResult(
  for result: CQuickJSValue,
  in contextRef: OpaquePointer
) -> JSResult<CQuickJSValue> {
  if JS_IsException(result) {
    let exception = JS_GetException(contextRef)
    return .exception(exception)
  }
  return .value(result)
}

func quickJSImmediateValue(tag: Int32, payload: Int32 = 0) -> CQuickJSValue {
  CQuickJSValue(u: JSValueUnion(int32: payload), tag: Int64(tag))
}
