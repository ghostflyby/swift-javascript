import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {

  let ref: JSValueRef
  let contextRef: JSGlobalContextRef

  init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  public func bindToStorage(_ storage: inout JSValueStorage) {
    storage.word0 = UInt64(UInt(bitPattern: ref))
    storage.word1 = UInt64(UInt(bitPattern: contextRef))
  }

  public init(storage: JSValueStorage) {
    self.ref = JSValueRef(bitPattern: UInt(storage.word0))!
    self.contextRef = JSGlobalContextRef(bitPattern: UInt(storage.word1))!
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
