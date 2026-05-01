import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCorePropertyKeyHandle: JSPropertyKeyManualReferenceCountedHandle,
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

public struct JavaScriptCorePreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle,
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
