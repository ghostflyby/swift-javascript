@inline(__always)
func _bridgeJavaScriptCoreContext<E: JSEngine>(
  _ context: borrowing SwiftJavaScript.JSInstantContext<E>
) -> SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine> {
  precondition(
    E.self == JavaScriptCoreEngine.self,
    "This conversion path only supports JavaScriptCoreEngine"
  )

  let handle = unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
  return SwiftJavaScript.JSInstantContext<JavaScriptCoreEngine>(handle: handle)
}

@inline(__always)
func _bridgeJavaScriptCoreValue<E: JSEngine>(
  _ value: borrowing JSValue<E>
) -> SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
  precondition(
    E.self == JavaScriptCoreEngine.self,
    "This conversion path only supports JavaScriptCoreEngine"
  )

  let handle = unsafeBitCast(value.valueHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
  return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(handleValue: handle)
}

@inline(__always)
func _asGenericValue<E: JSEngine>(_ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>)
  -> JSValue<E>
{
  precondition(
    E.self == JavaScriptCoreEngine.self,
    "This conversion path only supports JavaScriptCoreEngine"
  )

  let handle = unsafeBitCast(value.valueHandle(), to: JSValueHandle<E>.self)
  return JSValue<E>(handleValue: handle)
}
