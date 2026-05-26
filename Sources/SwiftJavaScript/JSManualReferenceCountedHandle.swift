public protocol JSManualReferenceCountedHandle: Sendable {
  @discardableResult
  func retainReference() -> Bool

  @discardableResult
  func releaseReference() -> Bool
}

public protocol JSRuntimeManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSContextManualReferenceCountedHandle: JSManualReferenceCountedHandle, Hashable {}

/// Fixed-width words used by `JSValue` to store an engine-specific value handle.
///
/// Use a pointer-based storage if 24 bytes are insufficient.
public typealias JSValueStorageWords = (word0: UInt64, word1: UInt64, word2: UInt64)

public protocol JSValueManualReferenceCountedHandle: Hashable {

  associatedtype Context: JSContextManualReferenceCountedHandle

  func retainReference(in context: Context)

  func releaseReference(in context: Context)
}

public protocol JSClassManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSPropertyStringKeyManualReferenceCountedHandle: JSManualReferenceCountedHandle {}

public protocol JSPreparedScriptManualReferenceCountedHandle: JSManualReferenceCountedHandle {}
