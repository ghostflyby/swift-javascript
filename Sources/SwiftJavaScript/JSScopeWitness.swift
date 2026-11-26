/// Scope witness capability: the seam between the public scope protocols and
/// core's shared algorithms. It names the engine context identity the scope's
/// arena is keyed on, the arena frame the scope pushes, and the one
/// construction step every engine keeps to itself — wrapping a borrowed engine
/// handle in its own value view.
///
/// Package-only: neither the context identity nor the handle shape may appear
/// in a public signature any more. `JSValueScope`, the public face, only names
/// value-level requirements.
///
/// **`ContextHandle` is a convention, not a compiler-checked invariant.** The
/// public `JSContext` no longer declares a context-handle type, so nothing
/// forces `ContextHandle` here to be `Context`'s own handle type; in principle
/// the handle passed to `makeValue(handle:)` and the context the view is built
/// for could come from different engines. Every conformance must therefore use
/// its context's own handle type as this alias (JSC: `JSCContextHandle`, QJS:
/// `QJSContextHandle`, mock: `MockContextHandle`) and keep it in sync with the
/// concrete value views it produces. This is the only type-level invariant the
/// dehandle migration gave up (design §7 item 19).
package protocol JSScopeWitness: JSValueScope, ~Copyable {
  /// The engine context identity every operation of this window uses; each
  /// conformance must alias it to its `Context`'s own handle type.
  associatedtype ContextHandle: JSContextRuntimeDriver
  var driverContextHandle: ContextHandle { get }
  /// The witness's own arena frame (persistent-handle resolution anchors there).
  var scopeFrame: ScopeFrame<ContextHandle> { get }
  /// The witness's local view for a handle already anchored on `scopeFrame`.
  func makeValue(handle: ContextHandle.ValueHandle) -> Value
}
