import JavaScriptCore
import SwiftJavaScript

extension JSRuntimeHandle: JSManualReferenceCountedHandle, JSRuntimeManualReferenceCountedHandle
where E == JavaScriptCoreEngine {
  @discardableResult
  public func retainReference() -> Bool {
    guard let rawRuntime: JavaScriptCoreRawRuntime = opaqueHandle(), rawRuntime.ownsRuntime else {
      return false
    }
    JSContextGroupRetain(rawRuntime.ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard let rawRuntime: JavaScriptCoreRawRuntime = opaqueHandle(), rawRuntime.ownsRuntime else {
      return false
    }
    JSContextGroupRelease(rawRuntime.ref)
    return true
  }
}

extension JSBorrowedContextHandle: JSManualReferenceCountedHandle,
  JSContextManualReferenceCountedHandle
where E == JavaScriptCoreEngine {
  @discardableResult
  public func retainReference() -> Bool {
    guard let rawContext: JavaScriptCoreRawContext = opaqueHandle(), rawContext.ownsContext else {
      return false
    }
    JSGlobalContextRetain(rawContext.ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard let rawContext: JavaScriptCoreRawContext = opaqueHandle(), rawContext.ownsContext else {
      return false
    }
    JSGlobalContextRelease(rawContext.ref)
    return true
  }
}

extension JavaScriptCoreValueHandle: JSManualReferenceCountedHandle {
  @discardableResult
  public func retainReference() -> Bool {
    JSValueProtect(rawValue.contextRef, rawValue.ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JSValueUnprotect(rawValue.contextRef, rawValue.ref)
    return true
  }
}
