import JavaScriptCore
import SwiftJavaScript

public struct JSCRuntimeHandle: JSRuntimeManualReferenceCountedHandle,
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

  public var engineType: JSCEngine.Type {
    JSCEngine.self
  }

  @discardableResult
  public func retainReference() -> Bool {
    guard ownsRuntime else {
      return false
    }
    JSContextGroupRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard ownsRuntime else {
      return false
    }
    JSContextGroupRelease(ref)
    return true
  }
}

extension JSCRuntimeHandle: Hashable {
  public static func == (lhs: JSCRuntimeHandle, rhs: JSCRuntimeHandle)
    -> Bool
  {
    lhs.ref == rhs.ref
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ref)
  }
}
