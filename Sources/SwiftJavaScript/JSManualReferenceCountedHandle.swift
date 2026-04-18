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

public protocol JSValueManualReferenceCountedHandle: JSManualReferenceCountedHandle {
  /// Binds the handle's reference to the provided storage, which is used for storing the reference in a type-erased manner.
  ///
  /// Use a pointer-based storage if 24 bytes are insufficient
  func bindToStorage(_ storage: inout InlineArray<3, UInt64>)

  /// Initializes a handle from the provided storage, which is used for storing the reference in a type-erased manner.
  init(storage: InlineArray<3, UInt64>)
}

public protocol JSClassManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSStringManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
