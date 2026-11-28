/// A self-owning prepared script.
///
/// The concrete type owns whatever engine representation the script needs.
/// Both engine wrappers are context-free: JavaScriptCore owns a
/// `JSStringRef` and QuickJS owns the source text, so either can outlive the
/// context that minted it. This protocol is a public marker only: the engine
/// script wrapper is engine-internal, and the `Context` association exists for
/// diagnostics and for the context's member-type equalities.
public protocol JSPreparedScript: Sendable, ~Copyable {
  /// The context type this script was prepared through. Nominal: both engine
  /// wrappers are context-free, and the association keeps the context
  /// member-type equalities expressible.
  associatedtype Context: JSContext
}
