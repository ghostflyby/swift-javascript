public protocol JSEngineRuntimeDriver {
  associatedtype Engine: JSEngine = Self
  associatedtype RuntimeHandle: JSRuntimeManualReferenceCountedHandle
  associatedtype ContextHandle: JSContextManualReferenceCountedHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ContextHandle == ValueHandle.Context
  associatedtype OwnedValueHandle: JSOwnedValueManualReferenceCountedHandle
  where
    OwnedValueHandle: ~Copyable,
    OwnedValueHandle.Context == ContextHandle,
    OwnedValueHandle.Borrowed == ValueHandle
  associatedtype ClassHandle: JSClassManualReferenceCountedHandle

  static var capabilities: JSEngineCapabilities { get }

  static func makeRuntimeHandle() -> RuntimeHandle
  static func makeBorrowedContextHandleFromRuntime(in runtime: RuntimeHandle) -> ContextHandle?

  static func globalObjectValueHandle(_ context: ContextHandle) -> ValueHandle?

  static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<Engine>,
    in context: ContextHandle
  ) -> OwnedValueHandle?

  static func valueTypeForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSType?

  static func toBooleanForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func toNumberForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Double

  static func toStringForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> String?

  // Value-creation factories return the ownership carrier: the engine
  // produces a new owning reference (+1 under reference counting), which
  // flows into a scope arena (or an owning-by-convention `JSValue`).

  static func makeStringValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> OwnedValueHandle?

  static func makeSymbolValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> OwnedValueHandle?

  static func makeNumberValueHandle(
    _ value: Double,
    _ context: ContextHandle
  ) -> OwnedValueHandle?

  static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: ContextHandle
  ) -> OwnedValueHandle?

  static func makeNullValueHandle(
    _ context: ContextHandle
  ) -> OwnedValueHandle?

  static func makeUndefinedValueHandle(
    _ context: ContextHandle
  ) -> OwnedValueHandle?

  static func makeObjectResultHandle(
    _ context: ContextHandle
  ) -> JSResult<OwnedValueHandle>?

  static func makeArrayResultHandle(
    _ context: ContextHandle
  ) -> JSResult<OwnedValueHandle>?

  static func isContextCompatibleWith(
    _ this: ContextHandle,
    _ that: ContextHandle
  ) -> Bool

  /// Returns the context data storage box for the given context, or nil if none installed.
  static func contextDataStorageBox(in context: ContextHandle) -> JSContextDataStorageBox?

  /// Installs or replaces the context data storage box. When `nil`, releases the old box if present.
  static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: ContextHandle
  )

  /// Release a value handle created by the engine that was not persisted or returned.
  /// QuickJS: calls JS_FreeValue. JSC: no-op (GC-managed).
  static func releaseCreatedHandle(_ handle: consuming OwnedValueHandle, in context: ContextHandle)
}

extension JSEngineRuntimeDriver {
  public static func releaseCreatedHandle(
    _ handle: consuming OwnedValueHandle, in context: ContextHandle
  ) {
    // Default: no-op (JSC — GC manages value lifetimes)
  }
}

extension JSEngineRuntimeDriver {

  public static func contextDataStorageBox(in context: ContextHandle) -> JSContextDataStorageBox? {
    _ = context
    return nil
  }

  public static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: ContextHandle
  ) {
    _ = storage
    _ = context
  }
}
