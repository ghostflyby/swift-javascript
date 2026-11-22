/// The engine's value-handle type surface.
///
/// Public value types (`JSValue`, callback values/arguments, prepared inputs)
/// store only handle tokens and a context handle; they do not need the
/// engine's operation capabilities. Constraining them on this protocol keeps
/// each type on the driver face it actually uses — operation extensions add
/// `JSEngineRuntimeDriver` / `JSEnginePropertyDriver` / … as needed.
public protocol JSEngineValueTypes {
  associatedtype ContextHandle: JSContextManualReferenceCountedHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle.Context == ContextHandle
  associatedtype OwnedValueHandle: JSOwnedValueManualReferenceCountedHandle
  where
    OwnedValueHandle: ~Copyable,
    OwnedValueHandle.Context == ContextHandle,
    OwnedValueHandle.Borrowed == ValueHandle
}

/// Context-side value operations (Stage 2B decomposition).
///
/// Requirements live on the context handle itself: operations are addressed
/// as `context.foo(handle)` instead of the former engine-static
/// `E.foo(handle, in: context)`. Each engine's `ContextHandle` type conforms;
/// the engine type keeps only lifecycle/capability requirements.
public protocol JSContextRuntimeDriver: JSContextManualReferenceCountedHandle {
  associatedtype Engine: JSEngineRuntimeDriver
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle.Context == Self
  associatedtype OwnedValueHandle: JSOwnedValueManualReferenceCountedHandle
  where
    OwnedValueHandle: ~Copyable,
    OwnedValueHandle.Context == Self,
    OwnedValueHandle.Borrowed == ValueHandle

  func globalObjectValueHandle() -> ValueHandle?

  func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<Engine>
  ) -> OwnedValueHandle?

  func valueTypeForHandle(_ value: ValueHandle) -> JSType?

  func toBooleanForHandle(_ value: ValueHandle) -> Bool

  func toNumberForHandle(_ value: ValueHandle) -> Double

  func toStringForHandle(_ value: ValueHandle) -> String?

  // Value-creation factories return the ownership carrier: the engine
  // produces a new owning reference (+1 under reference counting), which
  // flows into a scope arena (the current synchronous frame or the context
  // default scope; `JSValue` itself owns nothing).

  func makeStringValueHandle(_ value: String) -> OwnedValueHandle?

  func makeSymbolValueHandle(_ value: String) -> OwnedValueHandle?

  func makeNumberValueHandle(_ value: Double) -> OwnedValueHandle?

  func makeBooleanValueHandle(_ value: Bool) -> OwnedValueHandle?

  func makeNullValueHandle() -> OwnedValueHandle?

  func makeUndefinedValueHandle() -> OwnedValueHandle?

  func makeObjectResultHandle() -> JSResult<OwnedValueHandle>?

  func makeArrayResultHandle() -> JSResult<OwnedValueHandle>?

  func isContextCompatibleWith(_ other: Self) -> Bool

  /// Returns the context data storage box, or nil if none installed.
  func contextDataStorageBox() -> JSContextDataStorageBox?

  /// Installs or replaces the context data storage box. When `nil`, releases the old box if present.
  func installContextDataStorageBox(_ storage: JSContextDataStorageBox?)

  /// Release a value handle created by the engine that was not persisted or returned.
  /// QuickJS: calls JS_FreeValue. JSC: no-op (GC-managed).
  func releaseCreatedHandle(_ handle: consuming OwnedValueHandle)

  /// Claim an owned reference for a borrowed handle that no arena owns yet
  /// (e.g. a callback argument) so it can enter a scope arena (persist
  /// fallback, §3.6).
  /// JSC: identity — the target arena's explicit root is the anchor.
  /// QuickJS: duplicate (`JS_DupValue`), because the engine call frame only
  /// lends the original reference.
  func claimOwnedValueHandle(_ handle: ValueHandle) -> OwnedValueHandle

  /// Enter this context's explicit root for an arena-owned value (§3.7).
  /// JSC: `JSValueProtect`. Reference-counted engines: identity — the
  /// creation reference already keeps the value alive.
  func rootOwnedValueHandle(_ handle: borrowing OwnedValueHandle)

  /// Leave the explicit root taken by `rootOwnedValueHandle` (§3.7).
  /// JSC: `JSValueUnprotect`. Reference-counted engines: identity.
  func unrootOwnedValueHandle(_ handle: borrowing OwnedValueHandle)
}

// No default implementations: every context states its release, rooting,
// claim, and storage behavior explicitly. A silent no-op default would let a
// migrated engine keep compiling while leaking every created handle or
// dropping a required explicit root (GC-managed and reference-counted engines
// write their identity semantics out explicitly instead).

/// Engine-side descriptor: associated types, capabilities, and runtime/context
/// lifecycle. Value operations moved to `JSContextRuntimeDriver`, implemented
/// by `ContextHandle`.
public protocol JSEngineRuntimeDriver: JSEngineValueTypes
where
  ContextHandle: JSContextRuntimeDriver,
  ContextHandle.Engine == Engine,
  ContextHandle.ValueHandle == ValueHandle,
  ContextHandle.OwnedValueHandle == OwnedValueHandle
{
  associatedtype Engine: JSEngineRuntimeDriver = Self
  associatedtype RuntimeHandle: JSRuntimeManualReferenceCountedHandle
  associatedtype ClassHandle: JSClassManualReferenceCountedHandle

  static var capabilities: JSEngineCapabilities { get }

  static func makeRuntimeHandle() -> RuntimeHandle
  static func makeBorrowedContextHandleFromRuntime(in runtime: RuntimeHandle) -> ContextHandle?
}
