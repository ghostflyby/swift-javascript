import SwiftJavaScript

/// A persistent, Sendable identity for a JavaScriptCore value bound in a
/// context-side registry.
///
/// The registry keeps one rooted
/// engine reference and this object keeps only the binding's public identity
/// plus a weak view of the registry. The handle exposes no JavaScript
/// operation — resolving goes through `JSCContext`, `JSCInstantContext`, or
/// `JSCScope`, so the produced value enters the receiving frame's arena.
///
/// Lifecycle: minting claims and roots an independent
/// reference, copying the handle only bumps ARC, and the last owner's release
/// (or `invalidate()`) kills the identity immediately and schedules engine
/// settlement on the VM's serial executor. The registry is weak so a surviving
/// handle cannot keep the context alive.
public final class JSCPersistentHandle: SwiftJavaScript.JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity

  /// Weak by design (§2.6 in `docs/PERSISTENT_HANDLE_DESIGN.md`): keeping the
  /// registry alive from a handle would keep the whole context alive and make
  /// "container death yields nil" unreachable.
  private let registryReference: PersistentRegistryReference<JSCContextHandle>

  package init(
    identity: JSPersistentHandleIdentity,
    registry: JSPersistentHandleRegistry<JSCContextHandle>
  ) {
    self.identity = identity
    self.registryReference = PersistentRegistryReference(registry)
  }

  @discardableResult
  public func invalidate() -> Bool {
    registryReference.value?.release(identity) ?? false
  }

  deinit {
    _ = registryReference.value?.release(identity)
  }

  public static func == (lhs: JSCPersistentHandle, rhs: JSCPersistentHandle) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}
