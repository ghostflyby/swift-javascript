/// A self-owning property string key.
///
/// The concrete type keeps the engine context alive so the key can outlive the
/// `JSContext` actor. This protocol is a public marker only: the engine key
/// wrapper and its context-compatibility guard are engine-internal, and the
/// `Context` association exists for diagnostics and for the context's
/// member-type equalities.
public protocol JSPropertyStringKey: Sendable, ~Copyable {
  /// The context this key belongs to.
  associatedtype Context: JSContext
}
