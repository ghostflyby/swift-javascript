import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
  typealias CQuickJSValue = CQuickJSStatic.JSValue
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
  typealias CQuickJSValue = CQuickJSDynamic.JSValue
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
  typealias CQuickJSValue = CQuickJSSystem.JSValue
#endif

public enum QuickJSEngine: Sendable {
  public typealias RuntimeHandle = QuickJSRuntimeHandle
  public typealias ContextHandle = QuickJSContextHandle
  public typealias ValueHandle = QuickJSValueHandle
  public typealias OwnedValueHandle = QuickJSOwnedValueHandle
  public typealias ClassHandle = QuickJSClassHandle
  public typealias PropertyStringKeyHandle = QuickJSPropertyStringKeyHandle
  public typealias PreparedScriptHandle = QuickJSPreparedScriptHandle
}

func quickJSResultHandle(
  for result: CQuickJSValue,
  in contextRef: OpaquePointer
) -> JSResult<QuickJSValueHandle> {
  if JS_IsException(result) {
    let exception = JS_GetException(contextRef)
    return .exception(QuickJSValueHandle(ref: exception))
  }
  return .value(QuickJSValueHandle(ref: result))
}

func quickJSImmediateValue(tag: Int32, payload: Int32 = 0) -> CQuickJSValue {
  CQuickJSValue(u: JSValueUnion(int32: payload), tag: Int64(tag))
}
