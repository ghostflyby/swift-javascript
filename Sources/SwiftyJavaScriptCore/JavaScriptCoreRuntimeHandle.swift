import JavaScriptCore
import SwiftJavaScript

package struct JSCRuntimeHandle: JSRuntimeManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSContextGroupRef
  package let ownsRuntime: Bool

  package init(ref: JSContextGroupRef = JSContextGroupCreate()) {
    self.ref = ref
    self.ownsRuntime = true
  }

  package init(borrowing ref: JSContextGroupRef) {
    self.ref = ref
    self.ownsRuntime = false
  }

  package var engineType: JSCEngine.Type {
    JSCEngine.self
  }

  @discardableResult
  package func retainReference() -> Bool {
    guard ownsRuntime else {
      return false
    }
    JSContextGroupRetain(ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    guard ownsRuntime else {
      return false
    }
    JSContextGroupRelease(ref)
    return true
  }
}

extension JSCRuntimeHandle: Hashable {
  package static func == (lhs: JSCRuntimeHandle, rhs: JSCRuntimeHandle)
    -> Bool
  {
    lhs.ref == rhs.ref
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(ref)
  }
}
