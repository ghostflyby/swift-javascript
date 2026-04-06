import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  let ref: JSValueRef
  let contextRef: JSGlobalContextRef

  init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  var type: SwiftJavaScript.JSType {
    JavaScriptCoreEngine.valueType(of: ref, in: contextRef)
  }

  func toDouble() -> Double {
    JSValueToNumber(contextRef, ref, nil)
  }

  func toString() -> String? {
    guard let stringHandle = JSValueToStringCopy(contextRef, ref, nil) else {
      return nil
    }
    defer { JSStringRelease(stringHandle) }
    return String(
      jsStringHandle: JavaScriptCoreStringHandle(ref: stringHandle),
      engine: JavaScriptCoreEngine.self
    )
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
