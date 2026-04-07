public protocol JSManualReferenceCountedHandle: Sendable {
  @discardableResult
  func retainReference() -> Bool

  @discardableResult
  func releaseReference() -> Bool
}

public protocol JSRuntimeManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSContextManualReferenceCountedHandle: JSManualReferenceCountedHandle {
  func bindContextOwner(_ owner: AnyObject)
}

extension JSContextManualReferenceCountedHandle {
  public func bindContextOwner(_ owner: AnyObject) {
    _ = owner
  }
}

public protocol JSValueManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSClassManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSStringManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
