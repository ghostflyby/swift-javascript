/// Callback-exit handoff: temporary, persistent, or thrown.
///
/// Every form carries a **borrowed** handle whose backing reference is owned by
/// a scope arena (or by the engine's argument frame). The trampoline gives the
/// engine its own reference (QuickJS: `JS_DupValue`; JSC: GC-managed, no
/// reference action) instead of receiving a transferred owned handle, so the
/// carrier never participates in ownership settlement.
public protocol JSCallbackReturn: ~Copyable {
  /// The context the returned value belongs to.
  associatedtype Context: JSContext
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle == Context.ValueHandle

  /// The borrowed engine handle token carried by this handoff.
  borrowing func borrowHandle() -> ValueHandle

  /// Whether the handoff is a thrown exception. The trampoline reads only this
  /// flag and the borrowed handle; the temporary/persistent distinction is a
  /// construction-time semantic, not a runtime branch.
  var isException: Bool { get }
}
