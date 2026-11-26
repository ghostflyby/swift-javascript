/// A self-owning prepared script.
///
/// The concrete type keeps the engine context alive so the script can outlive
/// the `JSContext` actor. This protocol is a public marker only: the engine
/// script wrapper and its context-compatibility guard are engine-internal, and
/// the `Context` association exists for diagnostics and for the context's
/// member-type equalities.
public protocol JSPreparedScript: Sendable, ~Copyable {
  /// The context this script belongs to.
  associatedtype Context: JSContext
}
