public protocol _JSEngineTypedArrayDriver: _JSEngineRuntimeDriver {
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

extension _JSEngineTypedArrayDriver {
  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: ContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> ValueHandle? {
    fatalError(
      "_JSEngineTypedArrayDriver.makeArrayBufferWithBytesNoCopyHandle(in:bytes:byteLength:bytesDeallocator:deallocatorContext:) is not implemented"
    )
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int? {
    fatalError("_JSEngineTypedArrayDriver.arrayBufferByteLengthForHandle(_:in:) is not implemented")
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    fatalError("_JSEngineTypedArrayDriver.arrayBufferBytesPtrForHandle(_:in:) is not implemented")
  }

  public static func makeTypedArrayHandle(
    in context: ContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> ValueHandle? {
    fatalError("_JSEngineTypedArrayDriver.makeTypedArrayHandle(in:kind:length:) is not implemented")
  }

  public static func makeTypedArrayHandle(
    in context: ContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: ValueHandle
  ) -> ValueHandle? {
    fatalError(
      "_JSEngineTypedArrayDriver.makeTypedArrayHandle(in:kind:arrayBuffer:) is not implemented")
  }

  public static func makeTypedArrayHandle(
    in context: ContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: ValueHandle,
    byteOffset: Int,
    length: Int
  ) -> ValueHandle? {
    fatalError(
      "_JSEngineTypedArrayDriver.makeTypedArrayHandle(in:kind:arrayBuffer:byteOffset:length:) is not implemented"
    )
  }

  public static func typedArrayLengthForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int? {
    fatalError("_JSEngineTypedArrayDriver.typedArrayLengthForHandle(_:in:) is not implemented")
  }

  public static func typedArrayByteLengthForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int? {
    fatalError("_JSEngineTypedArrayDriver.typedArrayByteLengthForHandle(_:in:) is not implemented")
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Int? {
    fatalError("_JSEngineTypedArrayDriver.typedArrayByteOffsetForHandle(_:in:) is not implemented")
  }

  public static func typedArrayBufferForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineTypedArrayDriver.typedArrayBufferForHandle(_:in:) is not implemented")
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    fatalError("_JSEngineTypedArrayDriver.typedArrayBytesPtrForHandle(_:in:) is not implemented")
  }

  public static func isArrayBufferHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool {
    fatalError("_JSEngineTypedArrayDriver.isArrayBufferHandle(_:in:) is not implemented")
  }

  public static func typedArrayKindForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSTypedArrayKind? {
    fatalError("_JSEngineTypedArrayDriver.typedArrayKindForHandle(_:in:) is not implemented")
  }
}
