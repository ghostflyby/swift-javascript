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

public enum QuickJSEngine: Sendable, SendableMetatype {
  public typealias RuntimeHandle = QuickJSRuntimeHandle
  public typealias ContextHandle = QuickJSContextHandle
  public typealias ValueHandle = QuickJSValueHandle
  public typealias ClassHandle = QuickJSClassHandle
  public typealias StringHandle = QuickJSStringHandle
}

func quickJSResultHandle(
  for result: CQuickJSValue,
  in contextRef: OpaquePointer
) -> JSResult<QuickJSValueHandle> {
  if JS_IsException(result) {
    let exception = JS_GetException(contextRef)
    return .exception(QuickJSValueHandle(ref: exception, contextRef: contextRef))
  }
  return .value(QuickJSValueHandle(ref: result, contextRef: contextRef))
}

func quickJSImmediateValue(tag: Int32, payload: Int32 = 0) -> CQuickJSValue {
  CQuickJSValue(u: JSValueUnion(int32: payload), tag: Int64(tag))
}
