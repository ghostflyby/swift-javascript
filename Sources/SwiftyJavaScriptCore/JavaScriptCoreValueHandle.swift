import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  package typealias RawValue = JavaScriptCoreRawValue

  package let rawValue: RawValue

  package init(rawValue: RawValue) {
    self.rawValue = rawValue
  }
}

extension JavaScriptCoreEngine: @unchecked Sendable, JSEngine {
  public typealias RuntimeHandle = JSRuntimeHandle<JavaScriptCoreEngine>
  public typealias ContextHandle = JSBorrowedContextHandle<JavaScriptCoreEngine>
  public typealias ValueHandle = JavaScriptCoreValueHandle
}
