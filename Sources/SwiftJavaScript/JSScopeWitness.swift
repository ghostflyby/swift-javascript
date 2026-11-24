/// Scope witness capability. Signatures such as `borrowHandle(in:)` require
/// the *ability* to address a driver context handle, not a specific scope
/// type; the synchronous and manual scopes both conform. Fabricating a
/// temporary scope just to satisfy such a signature is unnecessary by design.
///
/// Package-only: it is the seam between the public scope protocols and core's
/// shared algorithms — the arena frame a scope pushes, and the one construction
/// step every engine keeps to itself, wrapping a borrowed handle in its own
/// value view. The user-facing requirements on `JSPropertyStringKey`/
/// `JSPreparedScript` are the `ContextHandle` overloads; the witness overloads
/// stay internal to the package.
package protocol JSScopeWitness: JSValueScope, ~Copyable {
  /// The witness's own arena frame. Persistent-handle resolution anchors its
  /// produced local view here (design §5.1/§5.2).
  var scopeFrame: ScopeFrame<ContextHandle> { get }
  /// Build the witness's local view for a handle already anchored on
  /// `scopeFrame`.
  func makeValue(handle: ContextHandle.ValueHandle) -> Value
}
