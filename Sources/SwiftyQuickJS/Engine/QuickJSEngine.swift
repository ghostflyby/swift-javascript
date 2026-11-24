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

public enum QJSEngine: Sendable {
  public typealias RuntimeHandle = QJSRuntimeHandle
  public typealias ContextHandle = QJSContextHandle
  public typealias ValueHandle = QJSValueHandle
  public typealias OwnedValueHandle = QJSOwnedValueHandle
  public typealias ClassHandle = QJSClassHandle
  public typealias PropertyStringKeyHandle = QJSPropertyStringKeyHandle
  public typealias PreparedScriptHandle = QJSPreparedScriptHandle
}

func quickJSResultHandle(
  for result: CQuickJSValue,
  in contextRef: OpaquePointer
) -> JSResult<QJSValueHandle> {
  if JS_IsException(result) {
    let exception = JS_GetException(contextRef)
    return .exception(QJSValueHandle(ref: exception))
  }
  return .value(QJSValueHandle(ref: result))
}

func quickJSImmediateValue(tag: Int32, payload: Int32 = 0) -> CQuickJSValue {
  CQuickJSValue(u: JSValueUnion(int32: payload), tag: Int64(tag))
}
