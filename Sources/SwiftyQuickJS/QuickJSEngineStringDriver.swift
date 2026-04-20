import SwiftJavaScript

extension QuickJSEngine: _JSEngineStringDriver {
  public static func stringLength(_ stringHandle: QuickJSStringHandle) -> Int {
    stringHandle.length
  }

  public static func stringCharacters(_ stringHandle: QuickJSStringHandle) -> UnsafePointer<UInt16>?
  {
    stringHandle.characters
  }

  public static func makeJSString(_ value: String) -> QuickJSStringHandle {
    QuickJSStringHandle(value)
  }

  public static func stringEquals(_ lhs: QuickJSStringHandle, _ rhs: QuickJSStringHandle) -> Bool {
    lhs.length == rhs.length
      && UnsafeBufferPointer(start: lhs.characters, count: lhs.length).elementsEqual(
        UnsafeBufferPointer(start: rhs.characters, count: rhs.length))
  }
}
