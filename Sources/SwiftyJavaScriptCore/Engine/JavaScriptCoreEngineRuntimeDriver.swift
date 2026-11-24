import JavaScriptCore
import SwiftJavaScript

extension JSCEngine: JSEngineRuntimeDriver, JSEnginePreparedScriptDriver {

  public static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  public static func makeRuntimeHandle() -> JSCRuntimeHandle {
    JSCRuntimeHandle()
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: JSCRuntimeHandle
  ) -> JSCContextHandle? {
    JSCContextHandle(runtime: runtime)
  }

  public static func globalObjectValueHandle(
    _ context: JSCContextHandle
  ) -> JSValueHandle<JSCEngine>? {
    guard let objectRef = JSContextGetGlobalObject(context.ref) else {
      return nil
    }
    return JSCValueHandle(ref: objectRef)
  }

  public static func contextDataStorageBox(in context: JSCContextHandle)
    -> JSContextDataStorageBox?
  {
    guard let privateData = JSObjectGetPrivate(context.globalObjectRef) else {
      return nil
    }
    return Unmanaged<JSContextDataStorageBox>.fromOpaque(privateData)
      .takeUnretainedValue()
  }

  public static func installContextDataStorageBox(
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

  public static func makeFunctionValueHandle(
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

  public static func makePreparedScriptHandle(
    _ source: String,
    in context: JSCContextHandle
  ) -> JSCPreparedScriptHandle? {
    _ = context
    let scriptRef = JSStringCreateWithCFString(source as CFString)!
    return JSCPreparedScriptHandle(ref: scriptRef)
  }

  public static func isPreparedScriptHandleCompatibleWithContext(
    _ script: JSCPreparedScriptHandle,
    in context: JSCContextHandle
  ) -> Bool {
    _ = script
    _ = context
    return true
  }

  public static func evaluatePreparedScriptResultHandle(
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

  public static func valueTypeForHandle(
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

  public static func toBooleanForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool {
    JSValueToBoolean(context.ref, value.ref)
  }

  public static func toNumberForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Double {
    JSValueToNumber(context.ref, value.ref, nil)
  }

  public static func toStringForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> String? {
    javaScriptCoreString(value.ref, in: context.ref)
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle.adopting(javaScriptCoreMakeStringValue(value, in: context))
  }

  public static func makeSymbolValueHandle(
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

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle(
      ref: JSValueMakeNumber(context.ref, value)!
    )
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle(
      ref: JSValueMakeBoolean(context.ref, value)!
    )
  }

  public static func makeNullValueHandle(_ context: JSCContextHandle)
    -> JSOwnedValueHandle<JSCEngine>?
  {
    JSCOwnedValueHandle(
      ref: JSValueMakeNull(context.ref)
    )
  }

  public static func makeUndefinedValueHandle(
    _ context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context))
  }

  public static func makeObjectResultHandle(
    _ context: JSCContextHandle
  ) -> JSResult<JSOwnedValueHandle<JSCEngine>>? {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(
        JSCOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context)))
    }
    return .value(JSCOwnedValueHandle(ref: objectRef))
  }

  public static func makeArrayResultHandle(
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

  public static func isContextCompatibleWith(
    _ this: JSCContextHandle,
    _ that: JSCContextHandle
  ) -> Bool {
    JSContextGetGroup(this.ref) == JSContextGetGroup(that.ref)
  }

}

// MARK: - Context-side driver conformance (Stage 2B)

extension JSCContextHandle: JSContextRuntimeDriver, JSContextPreparedScriptDriver {
  public typealias InstantContext = JSCInstantContext
  public typealias ValueHandle = JSCValueHandle
  public typealias OwnedValueHandle = JSCOwnedValueHandle
  public typealias PreparedScriptHandle = JSCPreparedScriptHandle

  public func globalObjectValueHandle() -> JSCValueHandle? {
    JSCEngine.globalObjectValueHandle(self)
  }

  public func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCOwnedValueHandle? {
    JSCEngine.makeFunctionValueHandle(named: name, callback: callback, in: self)
  }

  public func valueTypeForHandle(_ value: JSCValueHandle) -> SwiftJavaScript.JSType? {
    JSCEngine.valueTypeForHandle(value, in: self)
  }

  public func toBooleanForHandle(_ value: JSCValueHandle) -> Bool {
    JSCEngine.toBooleanForHandle(value, in: self)
  }

  public func toNumberForHandle(_ value: JSCValueHandle) -> Double {
    JSCEngine.toNumberForHandle(value, in: self)
  }

  public func toStringForHandle(_ value: JSCValueHandle) -> String? {
    JSCEngine.toStringForHandle(value, in: self)
  }

  public func makeStringValueHandle(_ value: String) -> JSCOwnedValueHandle? {
    JSCEngine.makeStringValueHandle(value, self)
  }

  public func makeSymbolValueHandle(_ value: String) -> JSCOwnedValueHandle? {
    JSCEngine.makeSymbolValueHandle(value, self)
  }

  public func makeNumberValueHandle(_ value: Double) -> JSCOwnedValueHandle? {
    JSCEngine.makeNumberValueHandle(value, self)
  }

  public func makeBooleanValueHandle(_ value: Bool) -> JSCOwnedValueHandle? {
    JSCEngine.makeBooleanValueHandle(value, self)
  }

  public func makeNullValueHandle() -> JSCOwnedValueHandle? {
    JSCEngine.makeNullValueHandle(self)
  }

  public func makeUndefinedValueHandle() -> JSCOwnedValueHandle? {
    JSCEngine.makeUndefinedValueHandle(self)
  }

  public func makeObjectResultHandle() -> JSResult<JSCOwnedValueHandle>? {
    JSCEngine.makeObjectResultHandle(self)
  }

  public func makeArrayResultHandle() -> JSResult<JSCOwnedValueHandle>? {
    JSCEngine.makeArrayResultHandle(self)
  }

  public func isContextCompatibleWith(_ other: JSCContextHandle) -> Bool {
    JSCEngine.isContextCompatibleWith(self, other)
  }

  public func contextDataStorageBox() -> JSContextDataStorageBox? {
    JSCEngine.contextDataStorageBox(in: self)
  }

  /// The engine-side swap runs on the context's VM thread: inline when the
  /// caller is isolated to it, otherwise queued on it.
  public func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    JSCEngine.swapContextDataStorageBox(storage, on: self) { context, storage in
      JSCEngine.installContextDataStorageBox(storage, in: context)
    }
  }

  /// JSC is GC-managed: created handles need no explicit release.
  public func releaseCreatedHandle(_ handle: consuming JSCOwnedValueHandle) {}

  /// Claiming a borrowed JSC reference is an identity operation: JSC has no
  /// reference count, and the target arena's explicit root (if any) is what
  /// keeps the value alive.
  public func claimOwnedValueHandle(
    _ handle: JSCValueHandle
  ) -> JSCOwnedValueHandle {
    JSCOwnedValueHandle.adopting(handle)
  }

  /// Explicit root for heap-resident scopes (context default scope): JSC's
  /// conservative stack scan cannot see arena storage, so protect on add.
  public func rootOwnedValueHandle(_ handle: borrowing JSCOwnedValueHandle) {
    JSValueProtect(ref, handle.ref)
  }

  /// Leave the explicit root taken by `rootOwnedValueHandle` (drain/unlink).
  public func unrootOwnedValueHandle(_ handle: borrowing JSCOwnedValueHandle) {
    JSValueUnprotect(ref, handle.ref)
  }

  public func makePreparedScriptHandle(_ source: String)
    -> JSCPreparedScriptHandle?
  {
    JSCEngine.makePreparedScriptHandle(source, in: self)
  }

  public func isPreparedScriptHandleCompatibleWithContext(
    _ script: JSCPreparedScriptHandle
  ) -> Bool {
    JSCEngine.isPreparedScriptHandleCompatibleWithContext(script, in: self)
  }

  public func evaluatePreparedScriptResultHandle(
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
