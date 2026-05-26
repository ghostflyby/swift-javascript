import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable, Hashable {
  public typealias Context = JavaScriptCoreContextHandle

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
