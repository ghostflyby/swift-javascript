import JavaScriptCore
import SwiftJavaScript

package struct JSCPropertyStringKeyHandle:
  JSPropertyStringKeyManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSStringRef

  package init(ref: JSStringRef) {
    self.ref = ref
  }

  @discardableResult
  package func retainReference() -> Bool {
    JSStringRetain(ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    JSStringRelease(ref)
    return true
  }
}

package struct JSCPreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSStringRef

  package init(ref: JSStringRef) {
    self.ref = ref
  }

  @discardableResult
  package func retainReference() -> Bool {
    JSStringRetain(ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    JSStringRelease(ref)
    return true
  }
}
