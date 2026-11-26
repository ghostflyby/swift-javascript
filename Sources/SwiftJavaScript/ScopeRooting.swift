/// Compile-time rooting strategy for a scope arena (design §3.7).
///
/// A synchronous scope relies on the engine's implicit root domain: JSC's
/// conservative stack scan keeps values alive while their frame is on the
/// stack, and reference-counted engines already own the creation reference.
/// A heap-resident (default/async) scope has no such implicit domain and
/// must root every arena element explicitly.
///
/// The tags are engine-agnostic policy: each engine's scope machinery takes
/// one as its `Rooting` parameter.
package protocol JSScopeRooting: Sendable {
  static var rootsArenaValues: Bool { get }
}

/// Synchronous scope strategy: arena entries are only bookkeeping.
package enum JSImplicitStackRoots: JSScopeRooting {
  package static var rootsArenaValues: Bool { false }
}

/// Default/async scope strategy: arena entries are explicitly rooted
/// (JSC `JSValueProtect` / `JSValueUnprotect`; identity on refcounted
/// engines, where the creation reference is the root).
package enum JSExplicitRoots: JSScopeRooting {
  package static var rootsArenaValues: Bool { true }
}
