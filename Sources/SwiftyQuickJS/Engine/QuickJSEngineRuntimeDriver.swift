import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QuickJSEngine: JSEngineRuntimeDriver, JSEnginePreparedScriptDriver {

  public static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  public static func makeRuntimeHandle() -> QuickJSRuntimeHandle {
    guard let runtime = JS_NewRuntime() else {
      preconditionFailure("QuickJS could not create runtime")
    }
    return QuickJSRuntimeHandle(ref: runtime)
  }

  public static func makeBorrowedContextHandleFromRuntime(in runtime: QuickJSRuntimeHandle)
    -> QuickJSContextHandle?
  {
    guard let context = JS_NewContext(runtime.ref) else {
      return nil
    }
    return QuickJSContextHandle(ref: context)
  }

  public static func globalObjectValueHandle(_ context: QuickJSContextHandle) -> QuickJSValueHandle?
  {
    // `JS_GetGlobalObject` returns a new reference; the context owns its
    // global object for its lifetime, so return a borrowed identity and
    // settle the duplicate immediately. Callers wrap it in a non-owning
    // local view, which no longer has a deinit to free it.
    let global = JS_GetGlobalObject(context.ref)
    defer { JS_FreeValue(context.ref, global) }
    return QuickJSValueHandle(ref: global)
  }

  public static func contextDataStorageBox(in context: QuickJSContextHandle)
    -> JSContextDataStorageBox?
  {
    guard let opaque = JS_GetContextOpaque(context.ref) else {
      return nil
    }
    return Unmanaged<JSContextDataStorageBox>.fromOpaque(opaque).takeUnretainedValue()
  }

  public static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: QuickJSContextHandle
  ) {
    if let oldOpaque = JS_GetContextOpaque(context.ref) {
      JS_SetContextOpaque(context.ref, nil)
      _ = Unmanaged<JSContextDataStorageBox>.fromOpaque(oldOpaque).takeRetainedValue()
    }
    if let storage = storage {
      JS_SetContextOpaque(context.ref, Unmanaged.passRetained(storage).toOpaque())
    }
  }

  public static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<QuickJSEngine>,
    in context: QuickJSContextHandle
  ) -> QuickJSOwnedValueHandle? {
    let callbackBox = Unmanaged.passRetained(Box(callback))
    let function = name.withCString {
      JS_NewCClosure(
        context.ref,
        quickJSFunctionCallback,
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
    return QuickJSOwnedValueHandle(ref: function)
  }

  public static func makePreparedScriptHandle(
    _ source: String,
    in context: QuickJSContextHandle
  ) -> QuickJSPreparedScriptHandle? {
    QuickJSPreparedScriptHandle(source: source, contextRef: context.ref)
  }

  public static func isPreparedScriptHandleCompatibleWithContext(
    _ script: QuickJSPreparedScriptHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    script.contextRef == context.ref
  }

  public static func evaluatePreparedScriptResultHandle(
    _ script: QuickJSPreparedScriptHandle,
    _ context: QuickJSContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QuickJSValueHandle>? {
    let fileName = sourceURL ?? "<eval>"
    let result = adjustedPreparedScriptSource(script, startingLineNumber: startingLineNumber)
      .withCCharPointer { sourcePointer, sourceCount in
        fileName.withCString { filePointer in
          JS_Eval(
            context.ref,
            sourcePointer,
            sourceCount,
            filePointer,
            Int32(JS_EVAL_TYPE_GLOBAL)
          )
        }
      }
    return quickJSResultHandle(for: result, in: context.ref)
  }

  public static func valueTypeForHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> JSType? {
    switch Int(value.ref.tag) {
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

  public static func toBooleanForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    JS_ToBool(context.ref, value.ref) == 1
  }

  public static func toNumberForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Double {
    var result = 0.0
    let status = JS_ToFloat64(context.ref, &result, value.ref)
    return status == 0 ? result : .nan
  }

  public static func toStringForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> String? {
    quickJSString(value.ref, in: context.ref)
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: QuickJSContextHandle
  ) -> QuickJSOwnedValueHandle? {
    let rawValue = value.withCString { JS_NewString(context.ref, $0) }
    return QuickJSOwnedValueHandle(ref: rawValue)
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: QuickJSContextHandle
  ) -> QuickJSOwnedValueHandle? {
    let rawValue = value.withCString { JS_NewSymbol(context.ref, $0, false) }
    return QuickJSOwnedValueHandle(ref: rawValue)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: QuickJSContextHandle
  ) -> QuickJSOwnedValueHandle? {
    QuickJSOwnedValueHandle(ref: JS_NewFloat64(context.ref, value))
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: QuickJSContextHandle
  ) -> QuickJSOwnedValueHandle? {
    let ref = CQuickJSValue(u: .init(int32: Int32(value ? 1 : 0)), tag: Int64(JS_TAG_BOOL))
    return QuickJSOwnedValueHandle(ref: ref)
  }

  public static func makeNullValueHandle(_ context: QuickJSContextHandle)
    -> QuickJSOwnedValueHandle?
  {
    QuickJSOwnedValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_NULL))
    )
  }

  public static func makeUndefinedValueHandle(_ context: QuickJSContextHandle)
    -> QuickJSOwnedValueHandle?
  {
    QuickJSOwnedValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
    )
  }

  public static func makeObjectResultHandle(
    _ context: QuickJSContextHandle
  ) -> JSResult<QuickJSOwnedValueHandle>? {
    switch quickJSResultHandle(for: JS_NewObject(context.ref), in: context.ref) {
    case .value(let handle):
      return .value(QuickJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      return .exception(QuickJSOwnedValueHandle.adopting(handle))
    }
  }

  public static func makeArrayResultHandle(
    _ context: QuickJSContextHandle
  ) -> JSResult<QuickJSOwnedValueHandle>? {
    switch quickJSResultHandle(for: JS_NewArray(context.ref), in: context.ref) {
    case .value(let handle):
      return .value(QuickJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      return .exception(QuickJSOwnedValueHandle.adopting(handle))
    }
  }

  public static func isContextCompatibleWith(
    _ this: QuickJSContextHandle,
    _ that: QuickJSContextHandle
  ) -> Bool {
    JS_GetRuntime(this.ref) == JS_GetRuntime(that.ref)
  }

  public static func releaseCreatedHandle(
    _ handle: consuming QuickJSOwnedValueHandle, in context: QuickJSContextHandle
  ) {
    JS_FreeValue(context.ref, handle.rawRef)
  }
}

private func adjustedPreparedScriptSource(
  _ script: QuickJSPreparedScriptHandle,
  startingLineNumber: Int32
) -> QuickJSEvaluatedScriptSource {
  guard startingLineNumber > 1 else {
    return .prepared(script)
  }
  return .adjusted(
    prefix: String(repeating: "\n", count: Int(startingLineNumber - 1)), script: script)
}

private enum QuickJSEvaluatedScriptSource {
  case prepared(QuickJSPreparedScriptHandle)
  case adjusted(prefix: String, script: QuickJSPreparedScriptHandle)

  func withCCharPointer<R>(_ body: (UnsafePointer<CChar>?, Int) -> R) -> R {
    switch self {
    case .prepared(let script):
      return script.withCString(body)
    case .adjusted(let prefix, let script):
      var source = prefix + script.source
      return source.withUTF8 { pointer in
        pointer.withMemoryRebound(to: CChar.self) { pointer in
          body(pointer.baseAddress, pointer.count)
        }
      }
    }
  }
}

private func quickJSFunctionCallback(
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

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let scope = JSInstantContext<QuickJSEngine>(handle: contextHandle)

  let callback = Unmanaged<Box<JSFunctionCallback<QuickJSEngine>>>.fromOpaque(opaque)
    .takeUnretainedValue()
    .value

  let thisValue = JSCallbackValue<QuickJSEngine>(
    handle: QuickJSValueHandle(ref: thisValueRef),
    context: contextHandle
  )

  let result = withQuickJSArguments(
    arguments, count: Int(argumentCount),
    contextRef: contextRef,
  ) { args in
    callback(scope, thisValue, args)
  }

  // QuickJS takes ownership of a C callback's return value and of the value
  // passed to JS_Throw. §7.2 decision: the handoff carries a borrowed handle
  // whose reference is owned by a scope arena (persistent values by the
  // context default scope), so the trampoline duplicates for every form —
  // temporary, persistent, and exception alike. The arena settles its own
  // reference at drain; the engine settles the duplicated one.
  if result.isException {
    return JS_Throw(contextRef, JS_DupValue(contextRef, result.handle.ref))
  }
  return JS_DupValue(contextRef, result.handle.ref)
}

private func quickJSFunctionCallbackFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<Box<JSFunctionCallback<QuickJSEngine>>>.fromOpaque(opaque).takeRetainedValue()
}

private func withQuickJSArguments<R: ~Copyable>(
  _ arguments: UnsafeMutablePointer<CQuickJSValue>?,
  count: Int,
  contextRef: OpaquePointer,
  _ body: (borrowing JSCallbackArguments<QuickJSEngine>) -> R
) -> R {
  let swiftArguments = JSCallbackArguments<QuickJSEngine>(
    count: count,
    borrowedValueHandleAt: { index in
      guard index >= 0, index < count, let arguments else {
        return nil
      }
      return QuickJSValueHandle(
        ref: arguments[index]
      )
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

extension JSVirtualMachine where E == QuickJSEngine {

  public func gc() {
    JS_RunGC(self.driverRuntimeHandle.ref)
  }
}

// MARK: - Context-side driver conformance (Stage 2B)

extension QuickJSContextHandle: JSContextRuntimeDriver, JSContextPreparedScriptDriver {
  public typealias Engine = QuickJSEngine
  public typealias ValueHandle = QuickJSValueHandle
  public typealias OwnedValueHandle = QuickJSOwnedValueHandle
  public typealias PreparedScriptHandle = QuickJSPreparedScriptHandle

  public func globalObjectValueHandle() -> QuickJSValueHandle? {
    QuickJSEngine.globalObjectValueHandle(self)
  }

  public func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<QuickJSEngine>
  ) -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeFunctionValueHandle(named: name, callback: callback, in: self)
  }

  public func valueTypeForHandle(_ value: QuickJSValueHandle) -> JSType? {
    QuickJSEngine.valueTypeForHandle(value, in: self)
  }

  public func toBooleanForHandle(_ value: QuickJSValueHandle) -> Bool {
    QuickJSEngine.toBooleanForHandle(value, in: self)
  }

  public func toNumberForHandle(_ value: QuickJSValueHandle) -> Double {
    QuickJSEngine.toNumberForHandle(value, in: self)
  }

  public func toStringForHandle(_ value: QuickJSValueHandle) -> String? {
    QuickJSEngine.toStringForHandle(value, in: self)
  }

  public func makeStringValueHandle(_ value: String) -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeStringValueHandle(value, self)
  }

  public func makeSymbolValueHandle(_ value: String) -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeSymbolValueHandle(value, self)
  }

  public func makeNumberValueHandle(_ value: Double) -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeNumberValueHandle(value, self)
  }

  public func makeBooleanValueHandle(_ value: Bool) -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeBooleanValueHandle(value, self)
  }

  public func makeNullValueHandle() -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeNullValueHandle(self)
  }

  public func makeUndefinedValueHandle() -> QuickJSOwnedValueHandle? {
    QuickJSEngine.makeUndefinedValueHandle(self)
  }

  public func makeObjectResultHandle() -> JSResult<QuickJSOwnedValueHandle>? {
    QuickJSEngine.makeObjectResultHandle(self)
  }

  public func makeArrayResultHandle() -> JSResult<QuickJSOwnedValueHandle>? {
    QuickJSEngine.makeArrayResultHandle(self)
  }

  public func isContextCompatibleWith(_ other: QuickJSContextHandle) -> Bool {
    QuickJSEngine.isContextCompatibleWith(self, other)
  }

  public func contextDataStorageBox() -> JSContextDataStorageBox? {
    QuickJSEngine.contextDataStorageBox(in: self)
  }

  public func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    QuickJSEngine.installContextDataStorageBox(storage, in: self)
  }

  public func releaseCreatedHandle(_ handle: consuming QuickJSOwnedValueHandle) {
    QuickJSEngine.releaseCreatedHandle(handle, in: self)
  }

  /// QuickJS is reference-counted: a borrowed identity from an engine call
  /// frame carries no reference of its own, so claiming duplicates it before
  /// the arena adopts the result.
  public func claimOwnedValueHandle(
    _ handle: QuickJSValueHandle
  ) -> QuickJSOwnedValueHandle {
    QuickJSOwnedValueHandle.adopting(
      QuickJSValueHandle(ref: JS_DupValue(ref, handle.rawRef)))
  }

  /// QuickJS is reference-counted: the creation reference itself is the
  /// root, so entering an explicit root is an identity operation (design
  /// §3.7). Drain still frees the creation reference via
  /// `releaseCreatedHandle`.
  public func rootOwnedValueHandle(_ handle: borrowing QuickJSOwnedValueHandle) {}

  /// Identity counterpart of `rootOwnedValueHandle` (§3.7).
  public func unrootOwnedValueHandle(_ handle: borrowing QuickJSOwnedValueHandle) {}

  public func makePreparedScriptHandle(_ source: String) -> QuickJSPreparedScriptHandle? {
    QuickJSEngine.makePreparedScriptHandle(source, in: self)
  }

  public func isPreparedScriptHandleCompatibleWithContext(
    _ script: QuickJSPreparedScriptHandle
  ) -> Bool {
    QuickJSEngine.isPreparedScriptHandleCompatibleWithContext(script, in: self)
  }

  public func evaluatePreparedScriptResultHandle(
    _ script: QuickJSPreparedScriptHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QuickJSValueHandle>? {
    QuickJSEngine.evaluatePreparedScriptResultHandle(
      script,
      self,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }
}
