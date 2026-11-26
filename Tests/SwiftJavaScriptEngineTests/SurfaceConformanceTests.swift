import SwiftJavaScript
import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

// MARK: - Surface conformance (compile-time)
//
// `JSContext` names every user-facing type of an engine and states each
// relationship once; the member protocols only alias back to their context. A
// conformance is therefore already the strongest assertion. This sink
// additionally proves each association from the *call site*, one type at a
// time: passing an engine's concrete type where the context's association is
// expected compiles only when the two are the same type.

private func checkSurface<C: SwiftJavaScript.JSContext>(
  _: C.Type,
  value: C.Value.Type,
  callbackReturn: C.CallbackReturn.Type,
  arguments: C.Arguments.Type,
  callbackArguments: C.CallbackArguments.Type,
  instantContext: C.InstantContext.Type,
  scope: C.Scope.Type,
  virtualMachine: C.VirtualMachine.Type,
  persistentHandle: C.PersistentHandle.Type,
  propertyStringKey: C.PropertyStringKey.Type,
  preparedScript: C.PreparedScript.Type,
  arrayBuffer: C.ArrayBuffer.Type,
  typedArray: C.TypedArray.Type,
  callArgument: C.CallArgument.Type,
  jsClass: C.Class.Type
) {
  // The member types reach each other only through the context: each one's
  // own `Context` is the engine's context, and the types a member aliases are
  // the context's. The call below compiles only while `JSContext` and the
  // member protocols still state these relationships.
  checkBelongsToContext(
    C.self, value: value, callbackReturn: callbackReturn,
    arguments: arguments, callbackArguments: callbackArguments, instantContext: instantContext,
    scope: scope, virtualMachine: virtualMachine, propertyStringKey: propertyStringKey,
    preparedScript: preparedScript, arrayBuffer: arrayBuffer, typedArray: typedArray,
    jsClass: jsClass)
}

/// The relationships generic code relies on, stated once. Stating them here
/// is not the assertion; calling this from `checkSurface` is, because that
/// call has to be discharged by the protocol definitions alone.
private func checkBelongsToContext<C: SwiftJavaScript.JSContext>(
  _: C.Type,
  value: C.Value.Type,
  callbackReturn: C.CallbackReturn.Type,
  arguments: C.Arguments.Type,
  callbackArguments: C.CallbackArguments.Type,
  instantContext: C.InstantContext.Type,
  scope: C.Scope.Type,
  virtualMachine: C.VirtualMachine.Type,
  propertyStringKey: C.PropertyStringKey.Type,
  preparedScript: C.PreparedScript.Type,
  arrayBuffer: C.ArrayBuffer.Type,
  typedArray: C.TypedArray.Type,
  jsClass: C.Class.Type
)
where
  C.Value.Context == C,
  C.CallbackReturn.Context == C,
  C.Arguments.Context == C,
  C.Arguments.Value == C.Value,
  C.CallbackArguments.Context == C,
  C.CallbackArguments.Value == C.Value,
  C.InstantContext.Context == C,
  C.InstantContext.PropertyStringKey == C.PropertyStringKey,
  C.InstantContext.Arguments == C.Arguments,
  C.Scope.Context == C,
  C.Scope.InstantContext == C.InstantContext,
  C.Scope.Value == C.Value,
  C.VirtualMachine.Context == C,
  C.PropertyStringKey.Context == C,
  C.PreparedScript.Context == C,
  C.ArrayBuffer.Context == C,
  C.ArrayBuffer.Value == C.Value,
  C.TypedArray.Context == C,
  C.TypedArray.Buffer == C.ArrayBuffer,
  C.Class.Context == C
{}

@Test func javaScriptCoreSurfaceSatisfiesAllEquations() {
  checkSurface(
    JSCContext.self,
    value: JSCValue.self,
    callbackReturn: JSCCallbackReturn.self,
    arguments: JSCArguments.self,
    callbackArguments: JSCCallbackArguments.self,
    instantContext: JSCInstantContext.self,
    scope: JSCScope.self,
    virtualMachine: JSCVirtualMachine.self,
    persistentHandle: JSCPersistentHandle.self,
    propertyStringKey: JSCPropertyStringKey.self,
    preparedScript: JSCPreparedScript.self,
    arrayBuffer: JSCArrayBuffer.self,
    typedArray: JSCTypedArray.self,
    callArgument: JSCCallArgument.self,
    jsClass: JSCClass.self
  )
}

@Test func quickJSSurfaceSatisfiesAllEquations() {
  checkSurface(
    QJSContext.self,
    value: QJSValue.self,
    callbackReturn: QJSCallbackReturn.self,
    arguments: QJSArguments.self,
    callbackArguments: QJSCallbackArguments.self,
    instantContext: QJSInstantContext.self,
    scope: QJSScope.self,
    virtualMachine: QJSVirtualMachine.self,
    persistentHandle: QJSPersistentHandle.self,
    propertyStringKey: QJSPropertyStringKey.self,
    preparedScript: QJSPreparedScript.self,
    arrayBuffer: QJSArrayBuffer.self,
    typedArray: QJSTypedArray.self,
    callArgument: QJSCallArgument.self,
    jsClass: QJSClass.self
  )
}
