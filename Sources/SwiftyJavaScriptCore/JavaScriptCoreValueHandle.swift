import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  let ref: JSValueRef
  let contextRef: JSGlobalContextRef

  init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  @discardableResult
  public func retainReference() -> Bool {
    JSValueProtect(contextRef, ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JSValueUnprotect(contextRef, ref)
    return true
  }
}
