import JavaScriptCore
import SwiftJavaScript

public struct JSCPropertyStringKeyHandle:
  JSPropertyStringKeyManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSStringRef

  package init(ref: JSStringRef) {
    self.ref = ref
  }

  @discardableResult
  public func retainReference() -> Bool {
    JSStringRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JSStringRelease(ref)
    return true
  }
}

public struct JSCPreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSStringRef

  package init(ref: JSStringRef) {
    self.ref = ref
  }

  @discardableResult
  public func retainReference() -> Bool {
    JSStringRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JSStringRelease(ref)
    return true
  }
}
