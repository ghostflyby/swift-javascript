/// A persistent, Sendable identity for a JavaScript value bound in a
/// context-side registry (design `docs/PERSISTENT_HANDLE_DESIGN.md`).
///
/// `(registry, slot, generation)` (design §1.3): the registry id answers
/// "which container" (never reused), the slot answers "which table cell", and
/// the generation distinguishes a reused cell from the identity that
/// previously occupied it (ABA).
///
/// Public because it is the one piece of the registry's identity state that
/// leaks into user-facing handles; the registry itself stays package.
public struct JSPersistentHandleIdentity: Sendable, Hashable {
  public let registry: UInt64
  public let slot: UInt32
  public let generation: UInt32

  public init(registry: UInt64, slot: UInt32, generation: UInt32) {
    self.registry = registry
    self.slot = slot
    self.generation = generation
  }
}

/// A handle that keeps one rooted engine reference alive across isolation
/// domains.
///
/// The handle itself is **identity only** — it exposes no JavaScript
/// operation. Recovering access goes through a scope witness, so the produced
/// local view enters the receiving frame's arena like every other value.
public protocol JSPersistentHandle: Sendable, Hashable {
  /// The binding identity (registry, slot, generation).
  var identity: JSPersistentHandleIdentity { get }

  /// Invalidate the binding immediately; engine settlement happens on the
  /// next serial executor turn. Idempotent and callable from any thread.
  ///
  /// - Returns: whether this call ended a still-live binding.
  @discardableResult
  func invalidate() -> Bool
}
