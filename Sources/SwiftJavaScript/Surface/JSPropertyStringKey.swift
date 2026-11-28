/// A self-owning property string key.
///
/// The concrete type keeps the engine reference alive so the key can outlive
/// the `JSContext` actor. This protocol is a public marker only: the engine
/// key wrapper is engine-internal, and the `Context` association exists for
/// diagnostics and for the context's member-type equalities. A key is not
/// context-affine: the engine binds it to the runtime (QuickJS atom) or holds
/// a context-free string (JavaScriptCore), so property operations may use it
/// from any context that addresses the same engine state.
public protocol JSPropertyStringKey: Sendable, ~Copyable {
  /// The context type this key was minted through. Nominal: keys are not
  /// context-affine, the association keeps the context member-type equalities
  /// expressible.
  associatedtype Context: JSContext
}
