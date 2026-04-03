import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  package typealias RawValue = JavaScriptCoreRawValue

  package let rawValue: RawValue

  package init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

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
