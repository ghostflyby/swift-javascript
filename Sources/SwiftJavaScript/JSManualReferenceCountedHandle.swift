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

/// Fixed-width words used by `JSValue` to store an engine-specific value handle.
///
/// Use a pointer-based storage if 24 bytes are insufficient.
public typealias JSValueStorageWords = (word0: UInt64, word1: UInt64, word2: UInt64)

public protocol JSValueManualReferenceCountedHandle: JSManualReferenceCountedHandle {
  /// The handle's reference encoded as fixed-width storage words.
  var storageWords: JSValueStorageWords { get }

  /// Initializes a handle from fixed-width storage words.
  init(storageWords: JSValueStorageWords)
}

public protocol JSClassManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSPropertyKeyManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSPreparedScriptManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
