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
