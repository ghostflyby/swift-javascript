public protocol JSManualReferenceCountedHandle: Sendable {
  @discardableResult
  func retainReference() -> Bool

  @discardableResult
  func releaseReference() -> Bool
}

public protocol JSRuntimeManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSContextManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSValueManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSStringManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
