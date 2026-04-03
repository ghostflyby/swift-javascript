package protocol JSManualReferenceCountedHandle {
  @discardableResult
  func retainReference() -> Bool

  @discardableResult
  func releaseReference() -> Bool
}

package protocol JSRuntimeManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

package protocol JSContextManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

package protocol JSValueManualReferenceCountedHandle: JSManualReferenceCountedHandle {
  associatedtype RawValue: Sendable

  init(rawValue: RawValue)

  var rawValue: RawValue { get }
}
