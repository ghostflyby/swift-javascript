import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

private enum QuickJSFunctionCallbackStorage {
  case surface(JSFunctionCallback<QJSInstantContext>)
}

extension QJSEngine {

  package static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  // MARK: - Runtime and context lifecycle

  package static func makeRuntime() -> OpaquePointer {
    guard let runtime = JS_NewRuntime() else {
      preconditionFailure("QuickJS could not create runtime")
    }
    // QuickJS's default 1 MB stack budget can exceed the stack of the thread
    // an executor runs on (a dedicated thread has roughly 512 KB), which lets
    // real recursion overflow before the logical check fires. Keep the limit
    // below that: stack top is recorded at runtime creation on the VM
    // executor and refreshed only on thread hand-offs.
    JS_SetMaxStackSize(runtime, 256 * 1024)
    return runtime
  }

  package static func releaseRuntime(_ runtime: OpaquePointer) {
    JS_FreeRuntime(runtime)
  }

  package static func makeContext(in runtime: OpaquePointer) -> OpaquePointer? {
    JS_NewContext(runtime)
  }

  /// The runtime a context belongs to. Engine work: the caller runs on the VM
  /// thread.
  package static func runtimeRef(for context: OpaquePointer) -> OpaquePointer {
    let runtime: OpaquePointer = JS_GetRuntime(context)
    return runtime
  }

  package static func isContextCompatibleWith(
    _ this: OpaquePointer,
    _ that: OpaquePointer
  ) -> Bool {
    JS_GetRuntime(this) == JS_GetRuntime(that)
  }

  // MARK: - Context data box

  package static func contextDataStorageBox(in context: OpaquePointer)
    -> JSContextDataStorageBox?
  {
    guard let opaque = JS_GetContextOpaque(context) else {
      return nil
    }
    return Unmanaged<JSContextDataStorageBox>.fromOpaque(opaque).takeUnretainedValue()
  }

  package static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: OpaquePointer
  ) {
    if let oldOpaque = JS_GetContextOpaque(context) {
      JS_SetContextOpaque(context, nil)
      _ = Unmanaged<JSContextDataStorageBox>.fromOpaque(oldOpaque).takeRetainedValue()
    }
    if let storage = storage {
      JS_SetContextOpaque(context, Unmanaged.passRetained(storage).toOpaque())
    }
  }

  // MARK: - Global object and functions

  /// The global object as a borrowed identity: the context owns its global
  /// object for its lifetime, so the duplicate is settled here and the raw
  /// value is handed to a non-owning local view.
  package static func globalObjectValue(_ context: OpaquePointer) -> CQuickJSValue? {
    let global = JS_GetGlobalObject(context)
    defer { JS_FreeValue(context, global) }
    return global
  }

  package static func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    let callbackBox = Unmanaged.passRetained(
      Box(QuickJSFunctionCallbackStorage.surface(callback)))
    let function = name.withCString {
      JS_NewCClosure(
        context,
        quickJSSurfaceFunctionCallback,
        $0,
        quickJSFunctionCallbackFinalizer,
        0,
        0,
        callbackBox.toOpaque()
      )
    }
    if JS_IsException(function) {
      _ = callbackBox.takeRetainedValue()
      return nil
    }
    return function
  }

  // MARK: - Scripts

  /// Evaluate `source` with the global eval type. A prepared script only
  /// carries the source text and the context that compiled it, so the driver
  /// takes the text directly.
  package static func evaluateScript(
    _ source: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1,
    in context: OpaquePointer
  ) -> JSResult<CQuickJSValue> {
    let fileName = sourceURL ?? "<eval>"
    let result = quickJSAdjustedSource(source, startingLineNumber: startingLineNumber)
      .withCCharPointer { sourcePointer, sourceCount in
        fileName.withCString { filePointer in
          JS_Eval(
            context,
            sourcePointer,
            sourceCount,
            filePointer,
            Int32(JS_EVAL_TYPE_GLOBAL)
          )
        }
      }
    return quickJSResult(for: result, in: context)
  }

  // MARK: - Value classification and conversion

  package static func valueType(_ value: CQuickJSValue) -> SwiftJavaScript.JSType? {
    switch Int(value.tag) {
    case JS_TAG_UNDEFINED:
      return .undefined
    case JS_TAG_NULL:
      return .null
    case JS_TAG_BOOL:
      return .boolean
    case JS_TAG_BIG_INT, JS_TAG_SHORT_BIG_INT:
      return .bigInt
    case JS_TAG_FLOAT64, JS_TAG_INT:
      return .number
    case JS_TAG_STRING:
      return .string
    case JS_TAG_SYMBOL:
      return .symbol
    case JS_TAG_OBJECT:
      return .object
    default:
      return nil
    }
  }

  package static func toBoolean(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool {
    return JS_ToBool(context, value) == 1
  }

  package static func toNumber(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Double {
    var result = 0.0
    let status = JS_ToFloat64(context, &result, value)
    return status == 0 ? result : .nan
  }

  package static func toString(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> String? {
    quickJSString(value, in: context)
  }

  // MARK: - Creation factories (one owned reference each)

  package static func makeString(
    _ value: String,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    return value.withCString { JS_NewString(context, $0) }
  }

  package static func makeSymbol(
    _ value: String,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    return value.withCString { JS_NewSymbol(context, $0, false) }
  }

  package static func makeNumber(
    _ value: Double,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    return JS_NewFloat64(context, value)
  }

  /// A boolean is an immediate: no engine call and no allocation.
  package static func makeBoolean(
    _ value: Bool,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    _ = context
    return CQuickJSValue(u: .init(int32: Int32(value ? 1 : 0)), tag: Int64(JS_TAG_BOOL))
  }

  package static func makeNull(in context: OpaquePointer) -> CQuickJSValue? {
    _ = context
    return quickJSImmediateValue(tag: Int32(JS_TAG_NULL))
  }

  package static func makeUndefined(in context: OpaquePointer) -> CQuickJSValue? {
    _ = context
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  package static func makeObjectResult(
    in context: OpaquePointer
  ) -> JSResult<CQuickJSValue>? {
    return quickJSResult(for: JS_NewObject(context), in: context)
  }

  package static func makeArrayResult(
    in context: OpaquePointer
  ) -> JSResult<CQuickJSValue>? {
    return quickJSResult(for: JS_NewArray(context), in: context)
  }
}

private func quickJSAdjustedSource(
  _ source: String,
  startingLineNumber: Int32
) -> QuickJSEvaluatedScriptSource {
  guard startingLineNumber > 1 else {
    return .plain(source)
  }
  return .adjusted(
    prefix: String(repeating: "\n", count: Int(startingLineNumber - 1)),
    source: source
  )
}

private enum QuickJSEvaluatedScriptSource {
  case plain(String)
  case adjusted(prefix: String, source: String)

  func withCCharPointer<R>(_ body: (UnsafePointer<CChar>?, Int) -> R) -> R {
    switch self {
    case .plain(let source):
      return source.withCString { pointer in
        body(pointer, source.utf8.count)
      }
    case .adjusted(let prefix, let source):
      var source = prefix + source
      return source.withUTF8 { pointer in
        pointer.withMemoryRebound(to: CChar.self) { pointer in
          body(pointer.baseAddress, pointer.count)
        }
      }
    }
  }
}

// MARK: - Surface callback trampoline (S6)
//
// QuickJS takes ownership of a C callback's return value and of the value
// passed to JS_Throw. §7.2 decision: the handoff carries a borrowed handle
// whose reference is owned by a scope arena (persistent values by the
// context default scope), so the trampoline duplicates for every form —
// temporary, persistent, and exception alike. The arena settles its own
// reference at drain; the engine settles the duplicated one.

private func quickJSSurfaceFunctionCallback(
  contextRef: OpaquePointer?,
  thisValueRef: CQuickJSValue,
  argumentCount: Int32,
  arguments: UnsafeMutablePointer<CQuickJSValue>?,
  _: Int32,
  opaque: UnsafeMutableRawPointer?
) -> CQuickJSValue {
  guard let contextRef, let opaque else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let scope = QJSInstantContext(contextRef: contextRef)

  guard
    case .surface(let callback) = Unmanaged<Box<QuickJSFunctionCallbackStorage>>
      .fromOpaque(opaque).takeUnretainedValue().value
  else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let thisValue = QJSValue(value: thisValueRef, contextRef: contextRef)

  let result = withQuickJSArguments(
    arguments, count: Int(argumentCount)
  ) { args in
    callback(scope, thisValue, args)
  }

  if result.isException {
    return JS_Throw(contextRef, JS_DupValue(contextRef, result.value))
  }
  return JS_DupValue(contextRef, result.value)
}

private func quickJSFunctionCallbackFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<Box<QuickJSFunctionCallbackStorage>>.fromOpaque(opaque).takeRetainedValue()
}

private func withQuickJSArguments<R: ~Copyable>(
  _ arguments: UnsafeMutablePointer<CQuickJSValue>?,
  count: Int,
  _ body: (borrowing QJSCallbackArguments) -> R
) -> R {
  let swiftArguments = QJSCallbackArguments(
    count: count,
    borrowedValueAt: { index in
      guard index >= 0, index < count, let arguments else {
        return nil
      }
      return arguments[index]
    }
  )
  return body(swiftArguments)
}

private func quickJSString(_ value: CQuickJSValue, in contextRef: OpaquePointer) -> String? {
  var length = 0
  guard let cString = JS_ToCStringLen2(contextRef, &length, value, false) else {
    return nil
  }
  defer { JS_FreeCString(contextRef, cString) }
  let bytes = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
  return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
}
