/// Context-side TypedArray/ArrayBuffer operations (Stage 2B decomposition).
package protocol JSContextTypedArrayDriver: JSContextRuntimeDriver {
  func makeArrayBufferWithBytesNoCopyHandle(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> ValueHandle?

  func arrayBufferByteLengthForHandle(_ value: ValueHandle) -> Int?

  func arrayBufferBytesPtrForHandle(
    _ value: ValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool)

  func makeTypedArrayHandle(kind: JSTypedArrayKind, length: Int) -> ValueHandle?

  func makeTypedArrayHandle(kind: JSTypedArrayKind, arrayBuffer: ValueHandle) -> ValueHandle?

  func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: ValueHandle,
    byteOffset: Int,
    length: Int
  ) -> ValueHandle?

  func typedArrayLengthForHandle(_ value: ValueHandle) -> Int?

  func typedArrayByteLengthForHandle(_ value: ValueHandle) -> Int?

  func typedArrayByteOffsetForHandle(_ value: ValueHandle) -> Int?

  func typedArrayBufferForHandle(_ value: ValueHandle) -> ValueHandle?

  func typedArrayBytesPtrForHandle(
    _ value: ValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool)

  func isArrayBufferHandle(_ value: ValueHandle) -> Bool

  func typedArrayKindForHandle(_ value: ValueHandle) -> JSTypedArrayKind?
}

/// Engine-side descriptor. TypedArray requirements now live on
/// `JSContextTypedArrayDriver`, implemented by `ContextHandle`.
package protocol JSEngineTypedArrayDriver: JSEngineRuntimeDriver
where ContextHandle: JSContextTypedArrayDriver {}
