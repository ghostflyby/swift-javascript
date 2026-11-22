import JavaScriptCore
import SwiftJavaScript

extension JavaScriptCoreEngine: JSEngineRuntimeDriver, JSEnginePreparedScriptDriver {

  public static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  public static func makeRuntimeHandle() -> JavaScriptCoreRuntimeHandle {
    JavaScriptCoreRuntimeHandle()
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: JavaScriptCoreRuntimeHandle
  ) -> JavaScriptCoreContextHandle? {
    JavaScriptCoreContextHandle(runtime: runtime)
  }

  public static func globalObjectValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let objectRef = JSContextGetGlobalObject(context.ref) else {
      return nil
    }
    return JavaScriptCoreValueHandle(ref: objectRef)
  }

  public static func contextDataStorageBox(in context: JavaScriptCoreContextHandle)
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
    in context: JavaScriptCoreContextHandle
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
    callback: @escaping JSFunctionCallback<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSOwnedValueHandle<JavaScriptCoreEngine>? {
    let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
    guard let functionRef = JSObjectMake(context.ref, context.functionClassRef, callbackRef) else {
      let callback = Unmanaged<Box<JSFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(
        callbackRef
      )
      .takeRetainedValue()
      _ = callback.value
      return JavaScriptCoreOwnedValueHandle.adopting(
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
    return JavaScriptCoreOwnedValueHandle(ref: functionRef)
  }

  public static func makePreparedScriptHandle(
    _ source: String,
    in context: JavaScriptCoreContextHandle
  ) -> JavaScriptCorePreparedScriptHandle? {
    _ = context
    let scriptRef = JSStringCreateWithCFString(source as CFString)!
    return JavaScriptCorePreparedScriptHandle(ref: scriptRef)
  }

  public static func isPreparedScriptHandleCompatibleWithContext(
    _ script: JavaScriptCorePreparedScriptHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    _ = script
    _ = context
    return true
  }

  public static func evaluatePreparedScriptResultHandle(
    _ script: JavaScriptCorePreparedScriptHandle,
    _ context: JavaScriptCoreContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
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
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
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
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    JSValueToBoolean(context.ref, value.ref)
  }

  public static func toNumberForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Double {
    JSValueToNumber(context.ref, value.ref, nil)
  }

  public static func toStringForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> String? {
    javaScriptCoreString(value.ref, in: context.ref)
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: JavaScriptCoreContextHandle
  ) -> JSOwnedValueHandle<JavaScriptCoreEngine>? {
    JavaScriptCoreOwnedValueHandle.adopting(javaScriptCoreMakeStringValue(value, in: context))
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: JavaScriptCoreContextHandle
  ) -> JSOwnedValueHandle<JavaScriptCoreEngine>? {
    // The string helper's generic result must stay Copyable; build the raw
    // ref inside and wrap the ownership carrier outside.
    let symbolRef = withJavaScriptCoreString(value) { stringHandle in
      JSValueMakeSymbol(context.ref, stringHandle)!
    }
    return JavaScriptCoreOwnedValueHandle(ref: symbolRef)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: JavaScriptCoreContextHandle
  ) -> JSOwnedValueHandle<JavaScriptCoreEngine>? {
    JavaScriptCoreOwnedValueHandle(
      ref: JSValueMakeNumber(context.ref, value)!
    )
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JavaScriptCoreContextHandle
  ) -> JSOwnedValueHandle<JavaScriptCoreEngine>? {
    JavaScriptCoreOwnedValueHandle(
      ref: JSValueMakeBoolean(context.ref, value)!
    )
  }

  public static func makeNullValueHandle(_ context: JavaScriptCoreContextHandle)
    -> JSOwnedValueHandle<JavaScriptCoreEngine>?
  {
    JavaScriptCoreOwnedValueHandle(
      ref: JSValueMakeNull(context.ref)
    )
  }

  public static func makeUndefinedValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSOwnedValueHandle<JavaScriptCoreEngine>? {
    JavaScriptCoreOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context))
  }

  public static func makeObjectResultHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSResult<JSOwnedValueHandle<JavaScriptCoreEngine>>? {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(
        JavaScriptCoreOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context)))
    }
    return .value(JavaScriptCoreOwnedValueHandle(ref: objectRef))
  }

  public static func makeArrayResultHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSResult<JSOwnedValueHandle<JavaScriptCoreEngine>>? {
    var exception: JSValueRef?
    let objectRef = JSObjectMakeArray(context.ref, 0, nil, &exception)
    if let exception {
      return .exception(JavaScriptCoreOwnedValueHandle(ref: exception))
    }
    guard let objectRef else {
      return .value(
        JavaScriptCoreOwnedValueHandle.adopting(javaScriptCoreMakeUndefined(in: context)))
    }
    return .value(JavaScriptCoreOwnedValueHandle(ref: objectRef))
  }

  public static func isContextCompatibleWith(
    _ this: JavaScriptCoreContextHandle,
    _ that: JavaScriptCoreContextHandle
  ) -> Bool {
    JSContextGetGroup(this.ref) == JSContextGetGroup(that.ref)
  }

}

// MARK: - Context-side driver conformance (Stage 2B)

extension JavaScriptCoreContextHandle: JSContextRuntimeDriver, JSContextPreparedScriptDriver {
  public typealias Engine = JavaScriptCoreEngine
  public typealias ValueHandle = JavaScriptCoreValueHandle
  public typealias OwnedValueHandle = JavaScriptCoreOwnedValueHandle
  public typealias PreparedScriptHandle = JavaScriptCorePreparedScriptHandle

  public func globalObjectValueHandle() -> JavaScriptCoreValueHandle? {
    JavaScriptCoreEngine.globalObjectValueHandle(self)
  }

  public func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<JavaScriptCoreEngine>
  ) -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeFunctionValueHandle(named: name, callback: callback, in: self)
  }

  public func valueTypeForHandle(_ value: JavaScriptCoreValueHandle) -> SwiftJavaScript.JSType? {
    JavaScriptCoreEngine.valueTypeForHandle(value, in: self)
  }

  public func toBooleanForHandle(_ value: JavaScriptCoreValueHandle) -> Bool {
    JavaScriptCoreEngine.toBooleanForHandle(value, in: self)
  }

  public func toNumberForHandle(_ value: JavaScriptCoreValueHandle) -> Double {
    JavaScriptCoreEngine.toNumberForHandle(value, in: self)
  }

  public func toStringForHandle(_ value: JavaScriptCoreValueHandle) -> String? {
    JavaScriptCoreEngine.toStringForHandle(value, in: self)
  }

  public func makeStringValueHandle(_ value: String) -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeStringValueHandle(value, self)
  }

  public func makeSymbolValueHandle(_ value: String) -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeSymbolValueHandle(value, self)
  }

  public func makeNumberValueHandle(_ value: Double) -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeNumberValueHandle(value, self)
  }

  public func makeBooleanValueHandle(_ value: Bool) -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeBooleanValueHandle(value, self)
  }

  public func makeNullValueHandle() -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeNullValueHandle(self)
  }

  public func makeUndefinedValueHandle() -> JavaScriptCoreOwnedValueHandle? {
    JavaScriptCoreEngine.makeUndefinedValueHandle(self)
  }

  public func makeObjectResultHandle() -> JSResult<JavaScriptCoreOwnedValueHandle>? {
    JavaScriptCoreEngine.makeObjectResultHandle(self)
  }

  public func makeArrayResultHandle() -> JSResult<JavaScriptCoreOwnedValueHandle>? {
    JavaScriptCoreEngine.makeArrayResultHandle(self)
  }

  public func isContextCompatibleWith(_ other: JavaScriptCoreContextHandle) -> Bool {
    JavaScriptCoreEngine.isContextCompatibleWith(self, other)
  }

  public func contextDataStorageBox() -> JSContextDataStorageBox? {
    JavaScriptCoreEngine.contextDataStorageBox(in: self)
  }

  public func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    JavaScriptCoreEngine.installContextDataStorageBox(storage, in: self)
  }

  /// JSC is GC-managed: created handles need no explicit release.
  public func releaseCreatedHandle(_ handle: consuming JavaScriptCoreOwnedValueHandle) {}

  /// Claiming a borrowed JSC reference is an identity operation: JSC has no
  /// reference count, and the target arena's explicit root (if any) is what
  /// keeps the value alive.
  public func claimOwnedValueHandle(
    _ handle: JavaScriptCoreValueHandle
  ) -> JavaScriptCoreOwnedValueHandle {
    JavaScriptCoreOwnedValueHandle.adopting(handle)
  }

  /// Explicit root for heap-resident scopes (context default scope): JSC's
  /// conservative stack scan cannot see arena storage, so protect on add.
  public func rootOwnedValueHandle(_ handle: borrowing JavaScriptCoreOwnedValueHandle) {
    JSValueProtect(ref, handle.ref)
  }

  /// Leave the explicit root taken by `rootOwnedValueHandle` (drain/unlink).
  public func unrootOwnedValueHandle(_ handle: borrowing JavaScriptCoreOwnedValueHandle) {
    JSValueUnprotect(ref, handle.ref)
  }

  public func makePreparedScriptHandle(_ source: String)
    -> JavaScriptCorePreparedScriptHandle?
  {
    JavaScriptCoreEngine.makePreparedScriptHandle(source, in: self)
  }

  public func isPreparedScriptHandleCompatibleWithContext(
    _ script: JavaScriptCorePreparedScriptHandle
  ) -> Bool {
    JavaScriptCoreEngine.isPreparedScriptHandleCompatibleWithContext(script, in: self)
  }

  public func evaluatePreparedScriptResultHandle(
    _ script: JavaScriptCorePreparedScriptHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JavaScriptCoreValueHandle>? {
    JavaScriptCoreEngine.evaluatePreparedScriptResultHandle(
      script,
      self,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }
}
