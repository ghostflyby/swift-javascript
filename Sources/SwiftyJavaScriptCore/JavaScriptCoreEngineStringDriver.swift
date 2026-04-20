import Foundation
import JavaScriptCore
import SwiftJavaScript

extension JavaScriptCoreEngine: _JSEngineStringDriver {
  public static func stringLength(_ stringHandle: JavaScriptCoreStringHandle) -> Int {
    JSStringGetLength(stringHandle.ref)
  }

  public static func stringCharacters(
    _ stringHandle: JavaScriptCoreStringHandle
  ) -> UnsafePointer<UInt16>? {
    JSStringGetCharactersPtr(stringHandle.ref)
  }

  public static func makeJSString(_ value: String) -> JavaScriptCoreStringHandle {
    JavaScriptCoreStringHandle(ref: JSStringCreateWithCFString(value as CFString))
  }

  public static func stringEquals(
    _ lhs: JavaScriptCoreStringHandle,
    _ rhs: JavaScriptCoreStringHandle
  ) -> Bool {
    JSStringIsEqual(lhs.ref, rhs.ref)
  }
}
