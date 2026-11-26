package protocol JSManualReferenceCountedHandle: Sendable {
  @discardableResult
  func retainReference() -> Bool

  @discardableResult
  func releaseReference() -> Bool
}

package protocol JSRuntimeManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

package protocol JSContextManualReferenceCountedHandle: JSManualReferenceCountedHandle, Hashable {}

/// Copyable borrow token for an engine value handle.
///
/// Copying has no side effect and confers no ownership: the underlying
/// engine reference (when the engine is reference-counted) is owned
/// elsewhere — by a scope arena, by the context default scope, or by the
/// engine itself.
package protocol JSValueManualReferenceCountedHandle: Hashable {

  associatedtype Context: JSContextManualReferenceCountedHandle

  /// The `~Copyable` ownership-carrier counterpart of this borrowed token.
  associatedtype Owned: JSOwnedValueManualReferenceCountedHandle
  where Owned: ~Copyable, Owned.Borrowed == Self, Owned.Context == Context

  func retainReference(in context: Context)

  func releaseReference(in context: Context)
}

/// The ownership carrier for an engine-created value reference.
///
/// `~Copyable` (SE-0503) so an owning reference can exist in exactly one
/// place: creation results (+1 under reference counting), scope-arena
/// elements, and ownership handoffs. Conversion to and from the Copyable
/// borrowed token is always explicit — `borrowed()` downgrades without
/// releasing, `adopting(_:)` claims an already-owning reference without
/// changing the reference count. `Equatable` (SE-0499) supports arena
/// identity checks; `Hashable` is deliberately not required because
/// noncopyable values cannot be collection elements.
package protocol JSOwnedValueManualReferenceCountedHandle: Equatable, ~Copyable {

  associatedtype Context: JSContextManualReferenceCountedHandle

  /// The Copyable borrow token sharing this handle's identity.
  associatedtype Borrowed: JSValueManualReferenceCountedHandle
  where Borrowed.Context == Context

  /// Explicit downgrade: yield the Copyable borrow token without
  /// releasing the owned reference.
  borrowing func borrowed() -> Borrowed

  /// Explicit upgrade: claim an already-owning reference held in borrowed
  /// form (e.g. an engine value-operation result) as owned. No reference
  /// counting happens here.
  static func adopting(_ handle: borrowing Borrowed) -> Self
}

package protocol JSClassManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

package protocol JSPropertyStringKeyManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

package protocol JSPreparedScriptManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
