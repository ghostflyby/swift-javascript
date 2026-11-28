/// A self-owning prepared script.
///
/// The concrete type owns whatever engine representation the script needs.
/// JavaScriptCore caches a `JSStringRef` and keeps its creating context alive
/// for settlement; QuickJS re-evaluates source text, so its script is a plain
/// context-free value. This protocol is a public marker only: the engine
/// script wrapper is engine-internal, and the `Context` association exists for
/// diagnostics and for the context's member-type equalities.
public protocol JSPreparedScript: Sendable, ~Copyable {
  /// The context type this script was prepared through. Nominal: the wrapper
  /// may be context-free (QuickJS) or keep its minting context alive
  /// (JavaScriptCore), and the association keeps the context member-type
  /// equalities expressible.
  associatedtype Context: JSContext
}
