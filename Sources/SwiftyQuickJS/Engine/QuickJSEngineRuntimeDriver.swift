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

  public static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  public static func makeRuntimeHandle() -> QJSRuntimeHandle {
    guard let runtime = JS_NewRuntime() else {
      preconditionFailure("QuickJS could not create runtime")
    }
    return QJSRuntimeHandle(ref: runtime)
  }

  public static func makeBorrowedContextHandleFromRuntime(in runtime: QJSRuntimeHandle)
    -> QJSContextHandle?
  {
    guard let context = JS_NewContext(runtime.ref) else {
      return nil
    }
    return QJSContextHandle(ref: context)
  }

  public static func globalObjectValueHandle(_ context: QJSContextHandle) -> QJSValueHandle? {
    // `JS_GetGlobalObject` returns a new reference; the context owns its
    // global object for its lifetime, so return a borrowed identity and
    // settle the duplicate immediately. Callers wrap it in a non-owning
    // local view, which no longer has a deinit to free it.
    let global = JS_GetGlobalObject(context.ref)
    defer { JS_FreeValue(context.ref, global) }
    return QJSValueHandle(ref: global)
  }

  public static func contextDataStorageBox(in context: QJSContextHandle)
    -> JSContextDataStorageBox?
  {
    guard let opaque = JS_GetContextOpaque(context.ref) else {
      return nil
    }
    return Unmanaged<JSContextDataStorageBox>.fromOpaque(opaque).takeUnretainedValue()
  }

  public static func installContextDataStorageBox(
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

  public static func makeFunctionValueHandle(
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

  public static func makePreparedScriptHandle(
    _ source: String,
    in context: QJSContextHandle
  ) -> QJSPreparedScriptHandle? {
    QJSPreparedScriptHandle(source: source, contextRef: context.ref)
  }

  public static func isPreparedScriptHandleCompatibleWithContext(
    _ script: QJSPreparedScriptHandle,
    in context: QJSContextHandle
  ) -> Bool {
    script.contextRef == context.ref
  }

  public static func evaluatePreparedScriptResultHandle(
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

  public static func valueTypeForHandle(
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

  public static func toBooleanForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool {
    JS_ToBool(context.ref, value.ref) == 1
  }

  public static func toNumberForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Double {
    var result = 0.0
    let status = JS_ToFloat64(context.ref, &result, value.ref)
    return status == 0 ? result : .nan
  }

  public static func toStringForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> String? {
    quickJSString(value.ref, in: context.ref)
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let rawValue = value.withCString { JS_NewString(context.ref, $0) }
    return QJSOwnedValueHandle(ref: rawValue)
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let rawValue = value.withCString { JS_NewSymbol(context.ref, $0, false) }
    return QJSOwnedValueHandle(ref: rawValue)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    QJSOwnedValueHandle(ref: JS_NewFloat64(context.ref, value))
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let ref = CQuickJSValue(u: .init(int32: Int32(value ? 1 : 0)), tag: Int64(JS_TAG_BOOL))
    return QJSOwnedValueHandle(ref: ref)
  }

  public static func makeNullValueHandle(_ context: QJSContextHandle)
    -> QJSOwnedValueHandle?
  {
    QJSOwnedValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_NULL))
    )
  }

  public static func makeUndefinedValueHandle(_ context: QJSContextHandle)
    -> QJSOwnedValueHandle?
  {
    QJSOwnedValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
    )
  }

  public static func makeObjectResultHandle(
    _ context: QJSContextHandle
  ) -> JSResult<QJSOwnedValueHandle>? {
    switch quickJSResultHandle(for: JS_NewObject(context.ref), in: context.ref) {
    case .value(let handle):
      return .value(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      return .exception(QJSOwnedValueHandle.adopting(handle))
    }
  }

  public static func makeArrayResultHandle(
    _ context: QJSContextHandle
  ) -> JSResult<QJSOwnedValueHandle>? {
    switch quickJSResultHandle(for: JS_NewArray(context.ref), in: context.ref) {
    case .value(let handle):
      return .value(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      return .exception(QJSOwnedValueHandle.adopting(handle))
    }
  }

  public static func isContextCompatibleWith(
    _ this: QJSContextHandle,
    _ that: QJSContextHandle
  ) -> Bool {
    JS_GetRuntime(this.ref) == JS_GetRuntime(that.ref)
  }

  public static func releaseCreatedHandle(
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
    return JS_Throw(contextRef, JS_DupValue(contextRef, result.borrowHandle().ref))
  }
  return JS_DupValue(contextRef, result.borrowHandle().ref)
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
  public typealias InstantContext = QJSInstantContext
  public typealias ValueHandle = QJSValueHandle
  public typealias OwnedValueHandle = QJSOwnedValueHandle
  public typealias PreparedScriptHandle = QJSPreparedScriptHandle

  public func globalObjectValueHandle() -> QJSValueHandle? {
    QJSEngine.globalObjectValueHandle(self)
  }

  public func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSOwnedValueHandle? {
    QJSEngine.makeFunctionValueHandle(named: name, callback: callback, in: self)
  }

  public func valueTypeForHandle(_ value: QJSValueHandle) -> JSType? {
    QJSEngine.valueTypeForHandle(value, in: self)
  }

  public func toBooleanForHandle(_ value: QJSValueHandle) -> Bool {
    QJSEngine.toBooleanForHandle(value, in: self)
  }

  public func toNumberForHandle(_ value: QJSValueHandle) -> Double {
    QJSEngine.toNumberForHandle(value, in: self)
  }

  public func toStringForHandle(_ value: QJSValueHandle) -> String? {
    QJSEngine.toStringForHandle(value, in: self)
  }

  public func makeStringValueHandle(_ value: String) -> QJSOwnedValueHandle? {
    QJSEngine.makeStringValueHandle(value, self)
  }

  public func makeSymbolValueHandle(_ value: String) -> QJSOwnedValueHandle? {
    QJSEngine.makeSymbolValueHandle(value, self)
  }

  public func makeNumberValueHandle(_ value: Double) -> QJSOwnedValueHandle? {
    QJSEngine.makeNumberValueHandle(value, self)
  }

  public func makeBooleanValueHandle(_ value: Bool) -> QJSOwnedValueHandle? {
    QJSEngine.makeBooleanValueHandle(value, self)
  }

  public func makeNullValueHandle() -> QJSOwnedValueHandle? {
    QJSEngine.makeNullValueHandle(self)
  }

  public func makeUndefinedValueHandle() -> QJSOwnedValueHandle? {
    QJSEngine.makeUndefinedValueHandle(self)
  }

  public func makeObjectResultHandle() -> JSResult<QJSOwnedValueHandle>? {
    QJSEngine.makeObjectResultHandle(self)
  }

  public func makeArrayResultHandle() -> JSResult<QJSOwnedValueHandle>? {
    QJSEngine.makeArrayResultHandle(self)
  }

  public func isContextCompatibleWith(_ other: QJSContextHandle) -> Bool {
    QJSEngine.isContextCompatibleWith(self, other)
  }

  public func contextDataStorageBox() -> JSContextDataStorageBox? {
    QJSEngine.contextDataStorageBox(in: self)
  }

  /// The engine-side swap runs on the context's VM thread: inline when the
  /// caller is isolated to it, otherwise queued on it.
  public func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    QJSEngine.swapContextDataStorageBox(storage, on: self) { context, storage in
      QJSEngine.installContextDataStorageBox(storage, in: context)
    }
  }

  public func releaseCreatedHandle(_ handle: consuming QJSOwnedValueHandle) {
    QJSEngine.releaseCreatedHandle(handle, in: self)
  }

  /// QuickJS is reference-counted: a borrowed identity from an engine call
  /// frame carries no reference of its own, so claiming duplicates it before
  /// the arena adopts the result.
  public func claimOwnedValueHandle(
    _ handle: QJSValueHandle
  ) -> QJSOwnedValueHandle {
    QJSOwnedValueHandle.adopting(
      QJSValueHandle(ref: JS_DupValue(ref, handle.rawRef)))
  }

  /// QuickJS is reference-counted: the creation reference itself is the
  /// root, so entering an explicit root is an identity operation (design
  /// §3.7). Drain still frees the creation reference via
  /// `releaseCreatedHandle`.
  public func rootOwnedValueHandle(_ handle: borrowing QJSOwnedValueHandle) {}

  /// Identity counterpart of `rootOwnedValueHandle` (§3.7).
  public func unrootOwnedValueHandle(_ handle: borrowing QJSOwnedValueHandle) {}

  public func makePreparedScriptHandle(_ source: String) -> QJSPreparedScriptHandle? {
    QJSEngine.makePreparedScriptHandle(source, in: self)
  }

  public func isPreparedScriptHandleCompatibleWithContext(
    _ script: QJSPreparedScriptHandle
  ) -> Bool {
    QJSEngine.isPreparedScriptHandleCompatibleWithContext(script, in: self)
  }

  public func evaluatePreparedScriptResultHandle(
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
