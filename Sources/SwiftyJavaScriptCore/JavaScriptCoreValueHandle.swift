import JavaScriptCore
import SwiftJavaScript

public struct JSCValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable,
  Hashable
{
  public typealias Context = JSCContextHandle
  public typealias Owned = JSCOwnedValueHandle

  let ref: JSValueRef

  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.ref == rhs.ref }
  public func hash(into hasher: inout Hasher) { hasher.combine(unsafeBitCast(ref, to: UInt.self)) }

  init(ref: JSValueRef) {
    self.ref = ref
  }

  public func retainReference(in context: JSCContextHandle) {
    JSValueProtect(context.ref, ref)
  }

  public func releaseReference(in context: JSCContextHandle) {
    JSValueUnprotect(context.ref, ref)
  }

}

/// Ownership carrier for a JavaScriptCore value reference (`~Copyable`).
/// JSC is GC-managed, so owning vs. borrowing is a type-level distinction
/// only — releasing is delegated to `JSCValueHandle` and to the
/// engine driver's no-op `releaseCreatedHandle`.
public struct JSCOwnedValueHandle: JSOwnedValueManualReferenceCountedHandle,
  Equatable, ~Copyable
{
  public typealias Context = JSCContextHandle
  public typealias Borrowed = JSCValueHandle

  let ref: JSValueRef

  init(ref: JSValueRef) {
    self.ref = ref
  }

  public borrowing func borrowed() -> JSCValueHandle {
    JSCValueHandle(ref: ref)
  }

  public static func adopting(_ handle: borrowing JSCValueHandle) -> Self {
    Self(ref: handle.ref)
  }

  public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    lhs.ref == rhs.ref
  }
}
