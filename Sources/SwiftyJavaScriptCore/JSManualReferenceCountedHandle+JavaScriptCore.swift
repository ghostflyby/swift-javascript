import JavaScriptCore
import SwiftJavaScript

extension JSRuntimeHandle: JSManualReferenceCountedHandle where E == JavaScriptCoreEngine {
  @discardableResult
  package func retainReference() -> Bool {
    guard let rawRuntime: JavaScriptCoreRawRuntime = opaqueHandle() else {
      return false
    }
    JSContextGroupRetain(rawRuntime.ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    guard let rawRuntime: JavaScriptCoreRawRuntime = opaqueHandle() else {
      return false
    }
    JSContextGroupRelease(rawRuntime.ref)
    return true
  }
}

extension JSBorrowedContextHandle: JSManualReferenceCountedHandle where E == JavaScriptCoreEngine {
  @discardableResult
  package func retainReference() -> Bool {
    guard let rawContext: JavaScriptCoreRawContext = opaqueHandle(), rawContext.ownsContext else {
      return false
    }
    JSGlobalContextRetain(rawContext.ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    guard let rawContext: JavaScriptCoreRawContext = opaqueHandle(), rawContext.ownsContext else {
      return false
    }
    JSGlobalContextRelease(rawContext.ref)
    return true
  }
}

extension JSValueHandle: JSManualReferenceCountedHandle where E == JavaScriptCoreEngine {
  @discardableResult
  package func retainReference() -> Bool {
    guard let rawValue: JavaScriptCoreRawValue = opaqueHandle() else {
      return false
    }
    JSValueProtect(rawValue.contextRef, rawValue.ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    guard let rawValue: JavaScriptCoreRawValue = opaqueHandle() else {
      return false
    }
    JSValueUnprotect(rawValue.contextRef, rawValue.ref)
    return true
  }
}
