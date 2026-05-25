import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  public typealias Context = JavaScriptCoreContextHandle

  let ref: JSValueRef

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
