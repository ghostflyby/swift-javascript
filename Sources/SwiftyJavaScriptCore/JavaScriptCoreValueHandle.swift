import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {

  let ref: JSValueRef
  let contextRef: JSGlobalContextRef

  init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  public func bindToStorage(_ storage: inout InlineArray<3, UInt64>) {
    storage[0] = UInt64(UInt(bitPattern: ref))
    storage[1] = UInt64(UInt(bitPattern: contextRef))
  }

  public init(storage: InlineArray<3, UInt64>) {
    self.ref = unsafeBitCast(storage[0], to: JSValueRef.self)
    self.contextRef = unsafeBitCast(storage[1], to: JSGlobalContextRef.self)
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
