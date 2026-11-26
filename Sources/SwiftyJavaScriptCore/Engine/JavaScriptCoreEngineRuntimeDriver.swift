import JavaScriptCore
import SwiftJavaScript

extension JSCEngine: JSEngineRuntimeDriver, JSEnginePreparedScriptDriver {

  package static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  package static func makeRuntimeHandle() -> JSCRuntimeHandle {
    JSCRuntimeHandle()
  }

  package static func makeBorrowedContextHandleFromRuntime(
    in runtime: JSCRuntimeHandle
  ) -> JSCContextHandle? {
    JSCContextHandle(runtime: runtime)
  }

  package static func globalObjectValueHandle(
    _ context: JSCContextHandle
  ) -> JSValueHandle<JSCEngine>? {
    guard let objectRef = JSContextGetGlobalObject(context.ref) else {
      return nil
    }
    return JSCValueHandle(ref: objectRef)
  }

  package static func contextDataStorageBox(in context: JSCContextHandle)
    -> JSContextDataStorageBox?
  {
    guard let privateData = JSObjectGetPrivate(context.globalObjectRef) else {
      return nil
    }
    return Unmanaged<JSContextDataStorageBox>.fromOpaque(privateData)
      .takeUnretainedValue()
  }

  package static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: JSCContextHandle
  ) {
    if let oldData = JSObjectGetPrivate(context.globalObjectRef) {
      JSObjectSetPrivate(context.globalObjectRef, nil)
      _ = Unmanaged<JSContextDataStorageBox>.fromOpaque(oldData).takeRetainedValue()
    }
    if let storage = storage {
      JSObjectSetPrivate(context.globalObjectRef, Unmanaged.passRetained(storage).toOpaque())
    }
  }

  package static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<JSCInstantContext>,
    in context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
    guard
      let functionRef = JSObjectMake(context.ref, context.surfaceFunctionClassRef, callbackRef)
    else {
      let callback = Unmanaged<Box<JSFunctionCallback<JSCInstantContext>>>.fromOpaque(callbackRef)
        .takeRetainedValue()
      _ = callback.value
      return JSCOwnedValueHandle.adopting(
        javaScriptCoreMakeUndefined(in: context))
    }
    if !name.isEmpty {
      withJavaScriptCoreString("name") { nameKey in
        var exception: JSValueRef?
        JSObjectSetProperty(
          context.ref,
          functionRef,
          nameKey,
          javaScriptCoreMakeStringValue(name, in: context).ref,
          javaScriptCorePropertyAttributes(from: [.dontEnum, .readOnly]),
          &exception
        )
      }
    }
    return JSCOwnedValueHandle(ref: functionRef)
  }

  package static func makePreparedScriptHandle(
    _ source: String,
    in context: JSCContextHandle
  ) -> JSCPreparedScriptHandle? {
    _ = context
    let scriptRef = JSStringCreateWithCFString(source as CFString)!
    return JSCPreparedScriptHandle(ref: scriptRef)
  }

  package static func isPreparedScriptHandleCompatibleWithContext(
    _ script: JSCPreparedScriptHandle,
    in context: JSCContextHandle
  ) -> Bool {
    _ = script
    _ = context
    return true
  }

  package static func evaluatePreparedScriptResultHandle(
    _ script: JSCPreparedScriptHandle,
    _ context: JSCContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    withOptionalJavaScriptCoreString(sourceURL) { sourceURLRef in
      var exception: JSValueRef?
      let resultRef = JSEvaluateScript(
        context.ref,
        script.ref,
        nil,
        sourceURLRef,
        startingLineNumber,
        &exception
      )
      return javaScriptCoreResult(value: resultRef, exception: exception, in: context)
    }
  }

  package static func valueTypeForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> SwiftJavaScript.JSType? {
    switch JSValueGetType(context.ref, value.ref) {
    case kJSTypeUndefined:
      return .undefined
    case kJSTypeNull:
      return .null
    case kJSTypeBoolean:
      return .boolean
    case kJSTypeNumber:
      return .number
    case kJSTypeString:
      return .string
    case kJSTypeSymbol:
      return .symbol
    case kJSTypeObject:
      return .object
    case kJSTypeBigInt:
      return .bigInt
    default:
      fatalError("Unknown JSType raw value: \(JSValueGetType(context.ref, value.ref))")
    }
  }

  package static func toBooleanForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool {
    JSValueToBoolean(context.ref, value.ref)
  }

  package static func toNumberForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Double {
    JSValueToNumber(context.ref, value.ref, nil)
  }

  package static func toStringForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> String? {
    javaScriptCoreString(value.ref, in: context.ref)
  }

  package static func makeStringValueHandle(
    _ value: String,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle.adopting(javaScriptCoreMakeStringValue(value, in: context))
  }

  package static func makeSymbolValueHandle(
    _ value: String,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    // The string helper's generic result must stay Copyable; build the raw
    // ref inside and wrap the ownership carrier outside.
    let symbolRef = withJavaScriptCoreString(value) { stringHandle in
      JSValueMakeSymbol(context.ref, stringHandle)!
    }
    return JSCOwnedValueHandle(ref: symbolRef)
  }

  package static func makeNumberValueHandle(
    _ value: Double,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle(
      ref: JSValueMakeNumber(context.ref, value)!
    )
  }

  package static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle(
      ref: JSValueMakeBoolean(context.ref, value)!
    )
  }

  package static func makeNullValueHandle(_ context: JSCContextHandle)
    -> JSOwnedValueHandle<JSCEngine>?
  {
    JSCOwnedValueHandle(
      ref: JSValueMakeNull(context.ref)
    )
  }

  package static func makeUndefinedValueHandle(
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context))
  }

  package static func makeObjectResultHandle(
    _ context: JSCContextHandle
  ) -> JSResult<JSOwnedValueHandle<JSCEngine>>? {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(
        JSCOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context)))
    }
    return .value(JSCOwnedValueHandle(ref: objectRef))
  }

  package static func makeArrayResultHandle(
    _ context: JSCContextHandle
  ) -> JSResult<JSOwnedValueHandle<JSCEngine>>? {
    var exception: JSValueRef?
    let objectRef = JSObjectMakeArray(context.ref, 0, nil, &exception)
    if let exception {
      return .exception(JSCOwnedValueHandle(ref: exception))
    }
    guard let objectRef else {
      return .value(
        JSCOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context)))
    }
    return .value(JSCOwnedValueHandle(ref: objectRef))
  }

  package static func isContextCompatibleWith(
    _ this: JSCContextHandle,
    _ that: JSCContextHandle
  ) -> Bool {
    JSContextGetGroup(this.ref) == JSContextGetGroup(that.ref)
  }

}

// MARK: - Context-side driver conformance (Stage 2B)

extension JSCContextHandle: JSContextRuntimeDriver, JSContextPreparedScriptDriver {
  package typealias InstantContext = JSCInstantContext
  package typealias ValueHandle = JSCValueHandle
  package typealias OwnedValueHandle = JSCOwnedValueHandle
  package typealias PreparedScriptHandle = JSCPreparedScriptHandle

  package func globalObjectValueHandle() -> JSCValueHandle? {
    JSCEngine.globalObjectValueHandle(self)
  }

  package func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCOwnedValueHandle? {
    JSCEngine.makeFunctionValueHandle(named: name, callback: callback, in: self)
  }

  package func valueTypeForHandle(_ value: JSCValueHandle) -> SwiftJavaScript.JSType? {
    JSCEngine.valueTypeForHandle(value, in: self)
  }

  package func toBooleanForHandle(_ value: JSCValueHandle) -> Bool {
    JSCEngine.toBooleanForHandle(value, in: self)
  }

  package func toNumberForHandle(_ value: JSCValueHandle) -> Double {
    JSCEngine.toNumberForHandle(value, in: self)
  }

  package func toStringForHandle(_ value: JSCValueHandle) -> String? {
    JSCEngine.toStringForHandle(value, in: self)
  }

  package func makeStringValueHandle(_ value: String) -> JSCOwnedValueHandle? {
    JSCEngine.makeStringValueHandle(value, self)
  }

  package func makeSymbolValueHandle(_ value: String) -> JSCOwnedValueHandle? {
    JSCEngine.makeSymbolValueHandle(value, self)
  }

  package func makeNumberValueHandle(_ value: Double) -> JSCOwnedValueHandle? {
    JSCEngine.makeNumberValueHandle(value, self)
  }

  package func makeBooleanValueHandle(_ value: Bool) -> JSCOwnedValueHandle? {
    JSCEngine.makeBooleanValueHandle(value, self)
  }

  package func makeNullValueHandle() -> JSCOwnedValueHandle? {
    JSCEngine.makeNullValueHandle(self)
  }

  package func makeUndefinedValueHandle() -> JSCOwnedValueHandle? {
    JSCEngine.makeUndefinedValueHandle(self)
  }

  package func makeObjectResultHandle() -> JSResult<JSCOwnedValueHandle>? {
    JSCEngine.makeObjectResultHandle(self)
  }

  package func makeArrayResultHandle() -> JSResult<JSCOwnedValueHandle>? {
    JSCEngine.makeArrayResultHandle(self)
  }

  package func isContextCompatibleWith(_ other: JSCContextHandle) -> Bool {
    JSCEngine.isContextCompatibleWith(self, other)
  }

  package func contextDataStorageBox() -> JSContextDataStorageBox? {
    JSCEngine.contextDataStorageBox(in: self)
  }

  /// The engine-side swap runs on the context's VM thread: inline when the
  /// caller is isolated to it, otherwise queued on it.
  package func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    JSCEngine.swapContextDataStorageBox(storage, on: self) { context, storage in
      JSCEngine.installContextDataStorageBox(storage, in: context)
    }
  }

  /// JSC is GC-managed: created handles need no explicit release.
  package func releaseCreatedHandle(_ handle: consuming JSCOwnedValueHandle) {}

  /// Claiming a borrowed JSC reference is an identity operation: JSC has no
  /// reference count, and the target arena's explicit root (if any) is what
  /// keeps the value alive.
  package func claimOwnedValueHandle(
    _ handle: JSCValueHandle
  ) -> JSCOwnedValueHandle {
    JSCOwnedValueHandle.adopting(handle)
  }

  /// Explicit root for heap-resident scopes (context default scope): JSC's
  /// conservative stack scan cannot see arena storage, so protect on add.
  package func rootOwnedValueHandle(_ handle: borrowing JSCOwnedValueHandle) {
    JSValueProtect(ref, handle.ref)
  }

  /// Leave the explicit root taken by `rootOwnedValueHandle` (drain/unlink).
  package func unrootOwnedValueHandle(_ handle: borrowing JSCOwnedValueHandle) {
    JSValueUnprotect(ref, handle.ref)
  }

  package func makePreparedScriptHandle(_ source: String)
    -> JSCPreparedScriptHandle?
  {
    JSCEngine.makePreparedScriptHandle(source, in: self)
  }

  package func isPreparedScriptHandleCompatibleWithContext(
    _ script: JSCPreparedScriptHandle
  ) -> Bool {
    JSCEngine.isPreparedScriptHandleCompatibleWithContext(script, in: self)
  }

  package func evaluatePreparedScriptResultHandle(
    _ script: JSCPreparedScriptHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.evaluatePreparedScriptResultHandle(
      script,
      self,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }
}
