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
  package typealias RuntimeHandle = QJSRuntimeHandle
  package typealias ContextHandle = QJSContextHandle
  package typealias ValueHandle = QJSValueHandle
  package typealias OwnedValueHandle = QJSOwnedValueHandle
  package typealias ClassHandle = QJSClassHandle
  package typealias PropertyStringKeyHandle = QJSPropertyStringKeyHandle
  package typealias PreparedScriptHandle = QJSPreparedScriptHandle
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
