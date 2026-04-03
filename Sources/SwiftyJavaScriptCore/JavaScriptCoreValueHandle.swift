import SwiftJavaScript

public struct JavaScriptCoreValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  package typealias RawValue = JavaScriptCoreRawValue

  package let rawValue: RawValue

  package init(rawValue: RawValue) {
    self.rawValue = rawValue
  }
}
