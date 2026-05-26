public protocol JSEngineRuntimeDriver {
  associatedtype Engine: JSEngine = Self
  associatedtype RuntimeHandle: JSRuntimeManualReferenceCountedHandle
  associatedtype ContextHandle: JSContextManualReferenceCountedHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ContextHandle == ValueHandle.Context
  associatedtype ClassHandle: JSClassManualReferenceCountedHandle

  static var capabilities: JSEngineCapabilities { get }

  static func makeRuntimeHandle() -> RuntimeHandle
  static func makeBorrowedContextHandleFromRuntime(in runtime: RuntimeHandle) -> ContextHandle?

  static func globalObjectValueHandle(_ context: ContextHandle) -> ValueHandle?

  static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<Engine>,
    in context: ContextHandle
  ) -> ValueHandle?

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

  static func makeStringValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeSymbolValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeNumberValueHandle(
    _ value: Double,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeNullValueHandle(
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeUndefinedValueHandle(
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeObjectResultHandle(
    _ context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func makeArrayResultHandle(
    _ context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func isContextCompatibleWith(
    _ this: ContextHandle,
    _ that: ContextHandle
  ) -> Bool

  static func makeStorageWords(value: ValueHandle, in context: ContextHandle) -> JSValueStorageWords

  static func fromStorageWords(_ storageWords: JSValueStorageWords) -> (ValueHandle, ContextHandle)

  /// Returns the context data storage box for the given context, or nil if none installed.
  static func contextDataStorageBox(in context: ContextHandle) -> JSContextDataStorageBox?

  /// Installs or replaces the context data storage box. When `nil`, releases the old box if present.
  static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: ContextHandle
  )

  /// Release a value handle created by the engine that was not persisted or returned.
  /// QuickJS: calls JS_FreeValue. JSC: no-op (GC-managed).
  static func releaseCreatedHandle(_ handle: ValueHandle, in context: ContextHandle)
}

extension JSEngineRuntimeDriver {
  public static func releaseCreatedHandle(_ handle: ValueHandle, in context: ContextHandle) {
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
