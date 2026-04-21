public protocol JSEngineStringDriver {
  associatedtype StringHandle: JSStringManualReferenceCountedHandle

  static func stringLength(_ stringHandle: StringHandle) -> Int
  static func stringCharacters(_ stringHandle: StringHandle) -> UnsafePointer<UInt16>?
  static func makeJSString(_ value: String) -> StringHandle
  static func stringEquals(_ lhs: StringHandle, _ rhs: StringHandle) -> Bool
}
