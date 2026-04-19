public protocol JSManualReferenceCountedHandle: Sendable {
  @discardableResult
  func retainReference() -> Bool

  @discardableResult
  func releaseReference() -> Bool
}

public protocol JSRuntimeManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSContextManualReferenceCountedHandle: JSManualReferenceCountedHandle {
  /// Binds the JSContext reference to the native handle,
  /// which can be used to later retrieve the JSContext instance associated with the handle.
  ///
  /// Provide a empty implementation if recovering the JSContext instance from the handle is not needed or not possible.
  func bindContextOwner<E: JSEngine>(_ owner: JSContext<E>) where E.ContextHandle == Self
}

public protocol JSValueManualReferenceCountedHandle: JSManualReferenceCountedHandle {
  /// Binds the handle's reference to the provided storage, which is used for storing the reference in a type-erased manner.
  ///
  /// Use a pointer-based storage if 24 bytes are insufficient
  func bindToStorage(_ storage: inout JSValueStorage)

  /// Initializes a handle from the provided storage, which is used for storing the reference in a type-erased manner.
  init(storage: JSValueStorage)
}

public protocol JSClassManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSStringManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
