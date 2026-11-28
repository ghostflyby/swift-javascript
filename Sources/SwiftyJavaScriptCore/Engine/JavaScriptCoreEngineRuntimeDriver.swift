import JavaScriptCore
import SwiftJavaScript

package func javaScriptCoreMakeBorrowedContextHandleFromRuntime(
  in runtime: JSContextGroupRef
) -> JSGlobalContextRef? {
  var definition = kJSClassDefinitionEmpty
  let globalObjectClass = JSClassCreate(&definition)
  guard let contextRef = JSGlobalContextCreateInGroup(runtime, globalObjectClass)
  else {
    return nil
  }
  if let globalObjectClass {
    JSClassRelease(globalObjectClass)
  }
  return contextRef
}

package func javaScriptCoreGlobalObjectValueHandle(
  _ context: JSGlobalContextRef
) -> JSValueRef? {
  guard let objectRef = JSContextGetGlobalObject(context) else {
    return nil
  }
  return objectRef
}

package func javaScriptCoreContextDataStorageBox(in context: JSGlobalContextRef)
  -> JSContextDataStorageBox?
{
  guard let privateData = JSObjectGetPrivate(JSContextGetGlobalObject(context)) else {
    return nil
  }
  return Unmanaged<JSContextDataStorageBox>.fromOpaque(privateData)
    .takeUnretainedValue()
}

package func javaScriptCoreInstallContextDataStorageBox(
  _ storage: JSContextDataStorageBox?,
  in context: JSGlobalContextRef
) {
  if let oldData = JSObjectGetPrivate(JSContextGetGlobalObject(context)) {
    JSObjectSetPrivate(JSContextGetGlobalObject(context), nil)
    _ = Unmanaged<JSContextDataStorageBox>.fromOpaque(oldData).takeRetainedValue()
  }
  if let storage = storage {
    JSObjectSetPrivate(
      JSContextGetGlobalObject(context), Unmanaged.passRetained(storage).toOpaque())
  }
}

package func javaScriptCoreMakeFunctionValueHandle(
  named name: String,
  callback: @escaping JSFunctionCallback<JSCInstantContext>,
  in context: JSGlobalContextRef
) -> JSValueRef? {
  let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
  guard
    let functionRef = JSObjectMake(
      context, javaScriptCoreSurfaceFunctionClass(for: context), callbackRef)
  else {
    let callback = Unmanaged<Box<JSFunctionCallback<JSCInstantContext>>>.fromOpaque(callbackRef)
      .takeRetainedValue()
    _ = callback.value
    return javaScriptCoreMakeUndefined(in: context)
  }
  if !name.isEmpty {
    withJavaScriptCoreString("name") { nameKey in
      var exception: JSValueRef?
      JSObjectSetProperty(
        context,
        functionRef,
        nameKey,
        javaScriptCoreMakeStringValue(name, in: context),
        javaScriptCorePropertyAttributes(from: [.dontEnum, .readOnly]),
        &exception
      )
    }
  }
  return functionRef
}

package func javaScriptCoreMakePreparedScriptHandle(
  _ source: String,
  in context: JSGlobalContextRef
) -> JSStringRef? {
  _ = context
  let scriptRef = JSStringCreateWithCFString(source as CFString)!
  return scriptRef
}

package func javaScriptCoreEvaluatePreparedScriptResultHandle(
  _ script: JSStringRef,
  _ context: JSGlobalContextRef,
  sourceURL: String? = nil,
  startingLineNumber: Int32 = 1
) -> JSResult<JSValueRef>? {
  withOptionalJavaScriptCoreString(sourceURL) { sourceURLRef in
    var exception: JSValueRef?
    let resultRef = JSEvaluateScript(
      context,
      script,
      nil,
      sourceURLRef,
      startingLineNumber,
      &exception
    )
    return javaScriptCoreResult(value: resultRef, exception: exception, in: context)
  }
}

package func javaScriptCoreValueTypeForHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> SwiftJavaScript.JSType? {
  switch JSValueGetType(context, value) {
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
    fatalError("Unknown JSType raw value: \(JSValueGetType(context, value))")
  }
}

package func javaScriptCoreToBooleanForHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  JSValueToBoolean(context, value)
}

package func javaScriptCoreToNumberForHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> Double {
  JSValueToNumber(context, value, nil)
}

package func javaScriptCoreToStringForHandle(
  _ value: JSValueRef,
  in context: JSGlobalContextRef
) -> String? {
  javaScriptCoreString(value, in: context)
}

package func javaScriptCoreMakeStringValueHandle(
  _ value: String,
  _ context: JSGlobalContextRef
) -> JSValueRef? {
  javaScriptCoreMakeStringValue(value, in: context)
}

package func javaScriptCoreMakeSymbolValueHandle(
  _ value: String,
  _ context: JSGlobalContextRef
) -> JSValueRef? {
  // The string helper's generic result must stay Copyable; build the raw
  // ref inside and wrap the ownership carrier outside.
  let symbolRef = withJavaScriptCoreString(value) { stringHandle in
    JSValueMakeSymbol(context, stringHandle)!
  }
  return symbolRef
}

package func javaScriptCoreMakeNumberValueHandle(
  _ value: Double,
  _ context: JSGlobalContextRef
) -> JSValueRef? {
  JSValueMakeNumber(context, value)!
}

package func javaScriptCoreMakeBooleanValueHandle(
  _ value: Bool,
  _ context: JSGlobalContextRef
) -> JSValueRef? {
  JSValueMakeBoolean(context, value)!
}

package func javaScriptCoreMakeNullValueHandle(_ context: JSGlobalContextRef)
  -> JSValueRef?
{
  JSValueMakeNull(context)
}

package func javaScriptCoreMakeUndefinedValueHandle(
  _ context: JSGlobalContextRef
) -> JSValueRef? {
  javaScriptCoreMakeUndefined(in: context)
}

package func javaScriptCoreMakeObjectResultHandle(
  _ context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  guard let objectRef = JSObjectMake(context, nil, nil) else {
    return .exception(javaScriptCoreMakeUndefined(in: context))
  }
  return .value(objectRef)
}

package func javaScriptCoreMakeArrayResultHandle(
  _ context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  var exception: JSValueRef?
  let objectRef = JSObjectMakeArray(context, 0, nil, &exception)
  if let exception {
    return .exception(exception)
  }
  guard let objectRef else {
    return .value(javaScriptCoreMakeUndefined(in: context))
  }
  return .value(objectRef)
}

private struct JavaScriptCoreSharedClassRef: @unchecked Sendable {
  let ref: JSClassRef
}

private let javaScriptCoreSurfaceFunctionClassRef = JavaScriptCoreSharedClassRef(
  ref: {
    var definition = makeJavaScriptCoreSurfaceFunctionClassDefinition()
    return JSClassCreate(&definition)!
  }()
)

package func javaScriptCoreSurfaceFunctionClass(for context: JSGlobalContextRef)
  -> JSClassRef
{
  _ = context
  return javaScriptCoreSurfaceFunctionClassRef.ref
}

// MARK: - Context-side driver conformance (Stage 2B)
