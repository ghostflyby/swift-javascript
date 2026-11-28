/// A self-owning property string key.
///
/// The concrete type owns its engine reference. This protocol is a public
/// marker only: the engine key wrapper is engine-internal, and the `Context`
/// association exists for diagnostics and for the context's member-type
/// equalities. A key is not context-affine:
///
/// - JavaScriptCore holds a context-free `JSStringRef`, so the key can be used
///   from any context, including after its minting context has died.
/// - QuickJS holds a runtime-scoped atom, so the key can be used from any
///   context of the same runtime while the context that minted it is alive.
public protocol JSPropertyStringKey: Sendable, ~Copyable {
  /// The context type this key was minted through. Nominal: keys are not
  /// context-affine, the association keeps the context member-type equalities
  /// expressible. Engine lifetime rules are documented on the protocol.
  associatedtype Context: JSContext
}
