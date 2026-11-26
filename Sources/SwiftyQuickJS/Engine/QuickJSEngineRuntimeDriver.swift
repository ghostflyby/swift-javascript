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

extension QJSEngine: JSEngineRuntimeDriver, JSEnginePreparedScriptDriver {

  package static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  package static func makeRuntimeHandle() -> QJSRuntimeHandle {
    guard let runtime = JS_NewRuntime() else {
      preconditionFailure("QuickJS could not create runtime")
    }
    return QJSRuntimeHandle(ref: runtime)
  }

  package static func makeBorrowedContextHandleFromRuntime(in runtime: QJSRuntimeHandle)
    -> QJSContextHandle?
  {
    guard let context = JS_NewContext(runtime.ref) else {
      return nil
    }
    return QJSContextHandle(ref: context)
  }

  package static func globalObjectValueHandle(_ context: QJSContextHandle) -> QJSValueHandle? {
    // `JS_GetGlobalObject` returns a new reference; the context owns its
    // global object for its lifetime, so return a borrowed identity and
    // settle the duplicate immediately. Callers wrap it in a non-owning
    // local view, which no longer has a deinit to free it.
    let global = JS_GetGlobalObject(context.ref)
    defer { JS_FreeValue(context.ref, global) }
    return QJSValueHandle(ref: global)
  }

  package static func contextDataStorageBox(in context: QJSContextHandle)
    -> JSContextDataStorageBox?
  {
    guard let opaque = JS_GetContextOpaque(context.ref) else {
      return nil
    }
    return Unmanaged<JSContextDataStorageBox>.fromOpaque(opaque).takeUnretainedValue()
  }

  package static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: QJSContextHandle
  ) {
    if let oldOpaque = JS_GetContextOpaque(context.ref) {
      JS_SetContextOpaque(context.ref, nil)
      _ = Unmanaged<JSContextDataStorageBox>.fromOpaque(oldOpaque).takeRetainedValue()
    }
    if let storage = storage {
      JS_SetContextOpaque(context.ref, Unmanaged.passRetained(storage).toOpaque())
    }
  }

  package static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>,
    in context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let callbackBox = Unmanaged.passRetained(
      Box(QuickJSFunctionCallbackStorage.surface(callback)))
    let function = name.withCString {
      JS_NewCClosure(
        context.ref,
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
    return QJSOwnedValueHandle(ref: function)
  }

  package static func makePreparedScriptHandle(
    _ source: String,
    in context: QJSContextHandle
  ) -> QJSPreparedScriptHandle? {
    QJSPreparedScriptHandle(source: source, contextRef: context.ref)
  }

  package static func isPreparedScriptHandleCompatibleWithContext(
    _ script: QJSPreparedScriptHandle,
    in context: QJSContextHandle
  ) -> Bool {
    script.contextRef == context.ref
  }

  package static func evaluatePreparedScriptResultHandle(
    _ script: QJSPreparedScriptHandle,
    _ context: QJSContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValueHandle>? {
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

  package static func valueTypeForHandle(
    _ value: QJSValueHandle,
    in _: QJSContextHandle
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

  package static func toBooleanForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool {
    JS_ToBool(context.ref, value.ref) == 1
  }

  package static func toNumberForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Double {
    var result = 0.0
    let status = JS_ToFloat64(context.ref, &result, value.ref)
    return status == 0 ? result : .nan
  }

  package static func toStringForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> String? {
    quickJSString(value.ref, in: context.ref)
  }

  package static func makeStringValueHandle(
    _ value: String,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let rawValue = value.withCString { JS_NewString(context.ref, $0) }
    return QJSOwnedValueHandle(ref: rawValue)
  }

  package static func makeSymbolValueHandle(
    _ value: String,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let rawValue = value.withCString { JS_NewSymbol(context.ref, $0, false) }
    return QJSOwnedValueHandle(ref: rawValue)
  }

  package static func makeNumberValueHandle(
    _ value: Double,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    QJSOwnedValueHandle(ref: JS_NewFloat64(context.ref, value))
  }

  package static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let ref = CQuickJSValue(u: .init(int32: Int32(value ? 1 : 0)), tag: Int64(JS_TAG_BOOL))
    return QJSOwnedValueHandle(ref: ref)
  }

  package static func makeNullValueHandle(_ context: QJSContextHandle)
    -> QJSOwnedValueHandle?
  {
    QJSOwnedValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_NULL))
    )
  }

  package static func makeUndefinedValueHandle(_ context: QJSContextHandle)
    -> QJSOwnedValueHandle?
  {
    QJSOwnedValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
    )
  }

  package static func makeObjectResultHandle(
    _ context: QJSContextHandle
  ) -> JSResult<QJSOwnedValueHandle>? {
    switch quickJSResultHandle(for: JS_NewObject(context.ref), in: context.ref) {
    case .value(let handle):
      return .value(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      return .exception(QJSOwnedValueHandle.adopting(handle))
    }
  }

  package static func makeArrayResultHandle(
    _ context: QJSContextHandle
  ) -> JSResult<QJSOwnedValueHandle>? {
    switch quickJSResultHandle(for: JS_NewArray(context.ref), in: context.ref) {
    case .value(let handle):
      return .value(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      return .exception(QJSOwnedValueHandle.adopting(handle))
    }
  }

  package static func isContextCompatibleWith(
    _ this: QJSContextHandle,
    _ that: QJSContextHandle
  ) -> Bool {
    JS_GetRuntime(this.ref) == JS_GetRuntime(that.ref)
  }

  package static func releaseCreatedHandle(
    _ handle: consuming QJSOwnedValueHandle, in context: QJSContextHandle
  ) {
    JS_FreeValue(context.ref, handle.rawRef)
  }
}

private func adjustedPreparedScriptSource(
  _ script: QJSPreparedScriptHandle,
  startingLineNumber: Int32
) -> QuickJSEvaluatedScriptSource {
  guard startingLineNumber > 1 else {
    return .prepared(script)
  }
  return .adjusted(
    prefix: String(repeating: "\n", count: Int(startingLineNumber - 1)), script: script)
}

private enum QuickJSEvaluatedScriptSource {
  case prepared(QJSPreparedScriptHandle)
  case adjusted(prefix: String, script: QJSPreparedScriptHandle)

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

  let contextHandle = QJSContextHandle(ref: contextRef)
  let scope = QJSInstantContext(handle: contextHandle)

  guard
    case .surface(let callback) = Unmanaged<Box<QuickJSFunctionCallbackStorage>>
      .fromOpaque(opaque).takeUnretainedValue().value
  else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let thisValue = QJSCallbackValue(
    handle: QJSValueHandle(ref: thisValueRef),
    contextHandle: contextHandle
  )

  let result = withQuickJSArguments(
    arguments, count: Int(argumentCount),
    contextRef: contextRef,
  ) { args in
    callback(scope, thisValue, args)
  }

  if result.isException {
    return JS_Throw(contextRef, JS_DupValue(contextRef, result.handle.ref))
  }
  return JS_DupValue(contextRef, result.handle.ref)
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
  contextRef: OpaquePointer,
  _ body: (borrowing QJSCallbackArguments) -> R
) -> R {
  let swiftArguments = QJSCallbackArguments(
    count: count,
    borrowedValueHandleAt: { index in
      guard index >= 0, index < count, let arguments else {
        return nil
      }
      return QJSValueHandle(
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

extension QJSContextHandle: JSContextRuntimeDriver, JSContextPreparedScriptDriver {
  package typealias InstantContext = QJSInstantContext
  package typealias ValueHandle = QJSValueHandle
  package typealias OwnedValueHandle = QJSOwnedValueHandle
  package typealias PreparedScriptHandle = QJSPreparedScriptHandle

  package func globalObjectValueHandle() -> QJSValueHandle? {
    QJSEngine.globalObjectValueHandle(self)
  }

  package func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSOwnedValueHandle? {
    QJSEngine.makeFunctionValueHandle(named: name, callback: callback, in: self)
  }

  package func valueTypeForHandle(_ value: QJSValueHandle) -> JSType? {
    QJSEngine.valueTypeForHandle(value, in: self)
  }

  package func toBooleanForHandle(_ value: QJSValueHandle) -> Bool {
    QJSEngine.toBooleanForHandle(value, in: self)
  }

  package func toNumberForHandle(_ value: QJSValueHandle) -> Double {
    QJSEngine.toNumberForHandle(value, in: self)
  }

  package func toStringForHandle(_ value: QJSValueHandle) -> String? {
    QJSEngine.toStringForHandle(value, in: self)
  }

  package func makeStringValueHandle(_ value: String) -> QJSOwnedValueHandle? {
    QJSEngine.makeStringValueHandle(value, self)
  }

  package func makeSymbolValueHandle(_ value: String) -> QJSOwnedValueHandle? {
    QJSEngine.makeSymbolValueHandle(value, self)
  }

  package func makeNumberValueHandle(_ value: Double) -> QJSOwnedValueHandle? {
    QJSEngine.makeNumberValueHandle(value, self)
  }

  package func makeBooleanValueHandle(_ value: Bool) -> QJSOwnedValueHandle? {
    QJSEngine.makeBooleanValueHandle(value, self)
  }

  package func makeNullValueHandle() -> QJSOwnedValueHandle? {
    QJSEngine.makeNullValueHandle(self)
  }

  package func makeUndefinedValueHandle() -> QJSOwnedValueHandle? {
    QJSEngine.makeUndefinedValueHandle(self)
  }

  package func makeObjectResultHandle() -> JSResult<QJSOwnedValueHandle>? {
    QJSEngine.makeObjectResultHandle(self)
  }

  package func makeArrayResultHandle() -> JSResult<QJSOwnedValueHandle>? {
    QJSEngine.makeArrayResultHandle(self)
  }

  package func isContextCompatibleWith(_ other: QJSContextHandle) -> Bool {
    QJSEngine.isContextCompatibleWith(self, other)
  }

  package func contextDataStorageBox() -> JSContextDataStorageBox? {
    QJSEngine.contextDataStorageBox(in: self)
  }

  /// The engine-side swap runs on the context's VM thread: inline when the
  /// caller is isolated to it, otherwise queued on it.
  package func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    QJSEngine.swapContextDataStorageBox(storage, on: self) { context, storage in
      QJSEngine.installContextDataStorageBox(storage, in: context)
    }
  }

  package func releaseCreatedHandle(_ handle: consuming QJSOwnedValueHandle) {
    QJSEngine.releaseCreatedHandle(handle, in: self)
  }

  /// QuickJS is reference-counted: a borrowed identity from an engine call
  /// frame carries no reference of its own, so claiming duplicates it before
  /// the arena adopts the result.
  package func claimOwnedValueHandle(
    _ handle: QJSValueHandle
  ) -> QJSOwnedValueHandle {
    QJSOwnedValueHandle.adopting(
      QJSValueHandle(ref: JS_DupValue(ref, handle.rawRef)))
  }

  /// QuickJS is reference-counted: the creation reference itself is the
  /// root, so entering an explicit root is an identity operation (design
  /// §3.7). Drain still frees the creation reference via
  /// `releaseCreatedHandle`.
  package func rootOwnedValueHandle(_ handle: borrowing QJSOwnedValueHandle) {}

  /// Identity counterpart of `rootOwnedValueHandle` (§3.7).
  package func unrootOwnedValueHandle(_ handle: borrowing QJSOwnedValueHandle) {}

  package func makePreparedScriptHandle(_ source: String) -> QJSPreparedScriptHandle? {
    QJSEngine.makePreparedScriptHandle(source, in: self)
  }

  package func isPreparedScriptHandleCompatibleWithContext(
    _ script: QJSPreparedScriptHandle
  ) -> Bool {
    QJSEngine.isPreparedScriptHandleCompatibleWithContext(script, in: self)
  }

  package func evaluatePreparedScriptResultHandle(
    _ script: QJSPreparedScriptHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.evaluatePreparedScriptResultHandle(
      script,
      self,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }
}
