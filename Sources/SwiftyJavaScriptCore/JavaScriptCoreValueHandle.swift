import JavaScriptCore
import SwiftJavaScript

package struct JSCValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable,
  Hashable
{
  package typealias Context = JSCContextHandle
  package typealias Owned = JSCOwnedValueHandle

  let ref: JSValueRef

  package static func == (lhs: Self, rhs: Self) -> Bool { lhs.ref == rhs.ref }
  package func hash(into hasher: inout Hasher) { hasher.combine(unsafeBitCast(ref, to: UInt.self)) }

  init(ref: JSValueRef) {
    self.ref = ref
  }

  package func retainReference(in context: JSCContextHandle) {
    JSValueProtect(context.ref, ref)
  }

  package func releaseReference(in context: JSCContextHandle) {
    JSValueUnprotect(context.ref, ref)
  }

}

/// Ownership carrier for a JavaScriptCore value reference (`~Copyable`).
/// JSC is GC-managed, so owning vs. borrowing is a type-level distinction
/// only — releasing is delegated to `JSCValueHandle` and to the
/// engine driver's no-op `releaseCreatedHandle`.
package struct JSCOwnedValueHandle: JSOwnedValueManualReferenceCountedHandle,
  Equatable, ~Copyable
{
  package typealias Context = JSCContextHandle
  package typealias Borrowed = JSCValueHandle

  let ref: JSValueRef

  init(ref: JSValueRef) {
    self.ref = ref
  }

  package borrowing func borrowed() -> JSCValueHandle {
    JSCValueHandle(ref: ref)
  }

  package static func adopting(_ handle: borrowing JSCValueHandle) -> Self {
    Self(ref: handle.ref)
  }

  package static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    lhs.ref == rhs.ref
  }
}
