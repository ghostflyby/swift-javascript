@inline(__always)
func _bridgeJavaScriptCoreContext<E: JSEngine>(
  _ context: borrowing JSEngineInstantContext<E>
) -> JSInstantContext {
  precondition(
    E.self == JavaScriptCoreEngine.self,
    "This conversion path only supports JavaScriptCoreEngine"
  )

  let handle = unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
  return JSInstantContext(handle: handle)
}

@inline(__always)
func _bridgeJavaScriptCoreValue<E: JSEngine>(
  _ value: borrowing JSEngineValue<E>
) -> JSValue {
  precondition(
    E.self == JavaScriptCoreEngine.self,
    "This conversion path only supports JavaScriptCoreEngine"
  )

  let handle = unsafeBitCast(value.valueHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
  return JSValue(handleValue: handle)
}

@inline(__always)
func _asGenericValue<E: JSEngine>(_ value: borrowing JSValue) -> JSEngineValue<E> {
  precondition(
    E.self == JavaScriptCoreEngine.self,
    "This conversion path only supports JavaScriptCoreEngine"
  )

  let handle = unsafeBitCast(value.valueHandle(), to: JSValueHandle<E>.self)
  return JSEngineValue<E>(handleValue: handle)
}
