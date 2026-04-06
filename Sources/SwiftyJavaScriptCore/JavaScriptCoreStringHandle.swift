import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreStringHandle: JSStringManualReferenceCountedHandle, @unchecked Sendable
{
  public let ref: JSStringRef

  public init(ref: JSStringRef) {
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
