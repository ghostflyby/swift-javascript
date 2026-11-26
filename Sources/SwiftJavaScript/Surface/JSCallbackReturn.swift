/// Callback-exit handoff: temporary, persistent, or thrown.
///
/// Every form carries a **borrowed** engine value whose backing reference is
/// owned by a scope arena (or by the engine's argument frame). The trampoline
/// gives the engine its own reference (QuickJS: `JS_DupValue`; JSC:
/// GC-managed, no reference action) instead of receiving a transferred owned
/// handle, so the carrier never participates in ownership settlement. Reading
/// that borrowed value is engine-internal: the concrete return type keeps the
/// handle in a package member and the protocol exposes only `isException`.
public protocol JSCallbackReturn: ~Copyable {
  /// The context the returned value belongs to.
  associatedtype Context: JSContext

  /// Whether the handoff is a thrown exception. The trampoline reads only this
  /// flag and the engine-internal handle; the temporary/persistent distinction
  /// is a construction-time semantic, not a runtime branch.
  var isException: Bool { get }
}
