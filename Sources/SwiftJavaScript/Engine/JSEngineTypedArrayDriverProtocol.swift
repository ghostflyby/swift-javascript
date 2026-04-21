public protocol JSEngineTypedArrayDriver: JSEngineRuntimeDriver {
  static func makeArrayBufferWithBytesNoCopyHandle(
    in context: ContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> ValueHandle?

  static func arrayBufferByteLengthForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int?

  static func arrayBufferBytesPtrForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool)

  static func makeTypedArrayHandle(
    in context: ContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> ValueHandle?

  static func makeTypedArrayHandle(
    in context: ContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: ValueHandle
  ) -> ValueHandle?

  static func makeTypedArrayHandle(
    in context: ContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: ValueHandle,
    byteOffset: Int,
    length: Int
  ) -> ValueHandle?

  static func typedArrayLengthForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int?

  static func typedArrayByteLengthForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int?

  static func typedArrayByteOffsetForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int?

  static func typedArrayBufferForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> ValueHandle?

  static func typedArrayBytesPtrForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool)

  static func isArrayBufferHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func typedArrayKindForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSTypedArrayKind?
}
