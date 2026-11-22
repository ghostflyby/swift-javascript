import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable,
  Hashable
{
  public typealias Context = JavaScriptCoreContextHandle
  public typealias Owned = JavaScriptCoreOwnedValueHandle

  let ref: JSValueRef

  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.ref == rhs.ref }
  public func hash(into hasher: inout Hasher) { hasher.combine(unsafeBitCast(ref, to: UInt.self)) }

  init(ref: JSValueRef) {
    self.ref = ref
  }

  public func retainReference(in context: JavaScriptCoreContextHandle) {
    JSValueProtect(context.ref, ref)
  }

  public func releaseReference(in context: JavaScriptCoreContextHandle) {
    JSValueUnprotect(context.ref, ref)
  }

}

/// Ownership carrier for a JavaScriptCore value reference (`~Copyable`).
/// JSC is GC-managed, so owning vs. borrowing is a type-level distinction
/// only — releasing is delegated to `JavaScriptCoreValueHandle` and to the
/// engine driver's no-op `releaseCreatedHandle`.
public struct JavaScriptCoreOwnedValueHandle: JSOwnedValueManualReferenceCountedHandle,
  Equatable, ~Copyable
{
  public typealias Context = JavaScriptCoreContextHandle
  public typealias Borrowed = JavaScriptCoreValueHandle

  let ref: JSValueRef

  init(ref: JSValueRef) {
    self.ref = ref
  }

  public borrowing func borrowed() -> JavaScriptCoreValueHandle {
    JavaScriptCoreValueHandle(ref: ref)
  }

  public static func adopting(_ handle: borrowing JavaScriptCoreValueHandle) -> Self {
    Self(ref: handle.ref)
  }

  public static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    lhs.ref == rhs.ref
  }
}
