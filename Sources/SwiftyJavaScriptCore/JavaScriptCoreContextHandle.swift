import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreContextHandle: JSContextManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSGlobalContextRef
  package let ownsContext: Bool

  package init(runtime: JavaScriptCoreRuntimeHandle) {
    self.ref = JSGlobalContextCreateInGroup(runtime.ref, nil)
    self.ownsContext = true
  }

  package init(borrowing ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = false
  }

  package init(adopting ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = true
  }

  public var engineType: JavaScriptCoreEngine.Type {
    JavaScriptCoreEngine.self
  }

  @discardableResult
  public func retainReference() -> Bool {
    guard ownsContext else {
      return false
    }
    JSGlobalContextRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard ownsContext else {
      return false
    }
    JSGlobalContextRelease(ref)
    return true
  }
}
