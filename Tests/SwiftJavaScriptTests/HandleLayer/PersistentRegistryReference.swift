import SwiftJavaScript

/// Weak holder for the registry. `@unchecked` covers only this box: the weak
/// reference is assigned once in `init`, read-only afterwards, and ARC's weak
/// load/clear is thread-safe. This keeps `JSPersistentHandle` implementations
/// honestly `Sendable` without an `@unchecked` promise on the public type
/// (design §1.2).
///
/// Package-level because every engine's surface handle implementation reuses
/// the same weak-reference discipline.
package final class PersistentRegistryReference<ContextHandle: JSContextRuntimeDriver>:
  @unchecked Sendable
{
  package weak var value: JSPersistentHandleRegistry<ContextHandle>?

  package init(_ value: JSPersistentHandleRegistry<ContextHandle>) {
    self.value = value
  }
}

// MARK: - Witness-side resolution

/// Witness-side resolution algorithm (design §5.2).
///
/// The produced view is a *copy*: the receiving frame claims a fresh owned
/// reference and tracks it, while the binding keeps its root. Both roots are
/// necessary — the binding's keeps the value alive without any scope, the
/// view's keeps it alive for the frame's lifetime (§5.3).
///
/// The witness's own arena receives the claim and the produced view is the
/// witness's own value type.
@available(*, noasync)
package func resolvePersistentHandle<W: JSScopeWitness & ~Copyable>(
  _ identity: JSPersistentHandleIdentity,
  in witness: borrowing W
) -> W.Value? {
  guard
    let registry = JSPersistentHandleRegistry<W.ContextHandle>.registry(
      for: witness.driverContextHandle)
  else {
    return nil
  }
  guard let borrowed = registry.borrowLive(identity) else { return nil }
  witness.scopeFrame.track(
    witness.driverContextHandle.claimOwnedValueHandle(borrowed))
  return witness.makeValue(handle: borrowed)
}
