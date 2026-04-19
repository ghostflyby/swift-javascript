import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {

  let ref: JSValueRef
  let contextRef: JSGlobalContextRef

  init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  public var storageWords: JSValueStorageWords {
    (
      word0: UInt64(UInt(bitPattern: ref)),
      word1: UInt64(UInt(bitPattern: contextRef)),
      word2: 0
    )
  }

  public init(storageWords: JSValueStorageWords) {
    self.ref = JSValueRef(bitPattern: UInt(storageWords.word0))!
    self.contextRef = JSGlobalContextRef(bitPattern: UInt(storageWords.word1))!
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
