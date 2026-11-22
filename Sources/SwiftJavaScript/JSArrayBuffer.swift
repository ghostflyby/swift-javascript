private let arrayBufferBytesDeallocator:
  (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void) = {
    bytes,
    _
    in
    bytes?.deallocate()
  }

public struct JSArrayBuffer<E: JSEngineTypedArrayDriver>: ~Copyable {
  let value: JSValue<E>
  let contextHandle: E.ContextHandle

  package init(storedValue: consuming JSValue<E>, contextHandle: E.ContextHandle) {
    self.value = storedValue
    self.contextHandle = contextHandle
  }

  /// Adopt another buffer's wrapped value without an extra retain (inits
  /// cannot assign `self =` once stored properties are not trivially
  /// destructible).
  private init(taking other: consuming JSArrayBuffer<E>) {
    let context = other.contextHandle
    let handle = other.value.takeHandle()
    self.value = JSValue(handleValue: handle, in: context)
    self.contextHandle = context
  }

  public init(byteLength: Int, in context: isolated JSContext<E> = #isolation)
  where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        JSArrayBuffer(byteLength: byteLength, in: callbackContext)
      })
  }

  public init(byteLength: Int, in context: borrowing JSInstantContext<E>) {
    precondition(byteLength >= 0, "ArrayBuffer byteLength must be non-negative")

    let bytes = Self.allocateZeroedBytes(byteLength: byteLength)
    let handle = context.driverContextHandle.makeArrayBufferWithBytesNoCopyHandle(
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: arrayBufferBytesDeallocator,
      deallocatorContext: nil
    )

    guard let handle else {
      arrayBufferBytesDeallocator(bytes, nil)
      preconditionFailure("Failed to create ArrayBuffer")
    }

    self.value = JSValue(handleValue: handle, in: context.driverContextHandle)
    self.contextHandle = context.driverContextHandle
  }

  public init(copying bytes: [UInt8], in context: isolated JSContext<E> = #isolation)
  where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        JSArrayBuffer(copying: bytes, in: callbackContext)
      })
  }

  public init(copying bytes: [UInt8], in context: borrowing JSInstantContext<E>) {
    self.init(copying: bytes.withUnsafeBytes { $0 }, in: context)
  }

  public init(
    copying bytes: UnsafeRawBufferPointer,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        JSArrayBuffer(copying: bytes, in: callbackContext)
      })
  }

  public init(
    copying bytes: UnsafeRawBufferPointer, in context: borrowing JSInstantContext<E>
  ) {
    let copiedBytes = Self.allocateCopy(of: bytes)
    let handle = context.driverContextHandle.makeArrayBufferWithBytesNoCopyHandle(
      bytes: copiedBytes,
      byteLength: bytes.count,
      bytesDeallocator: arrayBufferBytesDeallocator,
      deallocatorContext: nil
    )

    guard let handle else {
      arrayBufferBytesDeallocator(copiedBytes, nil)
      preconditionFailure("Failed to create ArrayBuffer from bytes")
    }

    self.value = JSValue(handleValue: handle, in: context.driverContextHandle)
    self.contextHandle = context.driverContextHandle
  }

  public init?(
    value: borrowing JSValue<E>, in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    guard
      let wrapped = context.withInstantContext({ callbackContext in
        JSArrayBuffer(value: value, in: callbackContext)
      })
    else {
      return nil
    }
    self.init(taking: wrapped)
  }

  public init?(value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>) {
    guard value.isArrayBuffer(in: context) else {
      return nil
    }

    self.value = JSValue(retaining: value)
    self.contextHandle = context.driverContextHandle
  }

  public var byteLength: Int {
    guard let length = contextHandle.arrayBufferByteLengthForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read ArrayBuffer byteLength")
    }
    return length
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue<E>) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let byteLength = self.byteLength
    let access = contextHandle.arrayBufferBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access ArrayBuffer bytes")
    }
    let rawBuffer = UnsafeRawBufferPointer(start: access.bytes, count: byteLength)
    return body(rawBuffer)
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = contextHandle.arrayBufferBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable ArrayBuffer bytes")
    }
    let rawBuffer = UnsafeMutableRawBufferPointer(start: access.bytes, count: byteLength)
    return body(rawBuffer)
  }

  private static func allocateZeroedBytes(byteLength: Int) -> UnsafeMutableRawPointer? {
    guard byteLength > 0 else {
      return nil
    }

    let pointer = UnsafeMutableRawPointer.allocate(
      byteCount: byteLength,
      alignment: MemoryLayout<UInt8>.alignment
    )
    pointer.initializeMemory(as: UInt8.self, repeating: 0, count: byteLength)
    return pointer
  }

  private static func allocateCopy(of bytes: UnsafeRawBufferPointer) -> UnsafeMutableRawPointer? {
    guard bytes.count > 0 else {
      return nil
    }

    let pointer = UnsafeMutableRawPointer.allocate(
      byteCount: bytes.count,
      alignment: MemoryLayout<UInt8>.alignment
    )
    pointer.copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
    return pointer
  }
}

extension JSArrayBuffer: JSValueEncodable {
  public func toJSValue<TargetEngine: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) -> JSValue<TargetEngine> {
    _ = context
    precondition(
      E.self == TargetEngine.self,
      "Cannot encode JSArrayBuffer across different JavaScript engine types"
    )

    let handle = unsafeBitCast(value.retainHandle(), to: JSValueHandle<TargetEngine>.self)
    return JSValue(handleValue: handle, in: context.driverContextHandle)
  }

  public func tryEncode<TargetEngine: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) throws(JSValueConversionError) -> JSValue<TargetEngine> {
    toJSValue(in: context)
  }
}

public struct JSTypedArray<E: JSEngineTypedArrayDriver>: ~Copyable {
  let value: JSValue<E>
  let contextHandle: E.ContextHandle

  package init(storedValue: consuming JSValue<E>, contextHandle: E.ContextHandle) {
    self.value = storedValue
    self.contextHandle = contextHandle
  }

  /// Adopt another array's wrapped value without an extra retain.
  private init(taking other: consuming JSTypedArray<E>) {
    let context = other.contextHandle
    let handle = other.value.takeHandle()
    self.value = JSValue(handleValue: handle, in: context)
    self.contextHandle = context
  }

  public init(
    type: JSTypedArrayKind,
    length: Int,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        JSTypedArray(type: type, length: length, in: callbackContext)
      })
  }

  public init(type: JSTypedArrayKind, length: Int, in context: borrowing JSInstantContext<E>) {
    precondition(length >= 0, "TypedArray length must be non-negative")

    guard
      let handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: type,
        length: length
      )
    else {
      preconditionFailure("Failed to create TypedArray")
    }

    self.value = JSValue(handleValue: handle, in: context.driverContextHandle)
    self.contextHandle = context.driverContextHandle
  }

  public init(
    type: JSTypedArrayKind,
    buffer: borrowing JSArrayBuffer<E>,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        JSTypedArray(
          type: type,
          buffer: buffer,
          byteOffset: byteOffset,
          length: length,
          in: callbackContext
        )
      })
  }

  public init(
    type: JSTypedArrayKind,
    buffer: borrowing JSArrayBuffer<E>,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: borrowing JSInstantContext<E>
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    let handle: JSValueHandle<E>?
    let bufferHandle = buffer.value.borrowHandle()

    if let length {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: type,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: type,
        arrayBuffer: bufferHandle
      )
    } else {
      let remainingLength = (buffer.byteLength - byteOffset) / type.bytesPerElement
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: type,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: remainingLength
      )
    }

    guard let handle else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }

    self.value = JSValue(handleValue: handle, in: context.driverContextHandle)
    self.contextHandle = context.driverContextHandle
  }

  public init?(
    value: borrowing JSValue<E>, in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    guard
      let wrapped = context.withInstantContext({ callbackContext in
        JSTypedArray(value: value, in: callbackContext)
      })
    else {
      return nil
    }
    self.init(taking: wrapped)
  }

  public init?(value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>) {
    guard value.typedArrayKind(in: context) != nil else {
      return nil
    }

    self.value = JSValue(retaining: value)
    self.contextHandle = context.driverContextHandle
  }

  public var kind: JSTypedArrayKind {
    guard let type = contextHandle.typedArrayKindForHandle(value.borrowHandle()) else {
      preconditionFailure("Wrapped JSValue is not a TypedArray")
    }
    return type
  }

  public var length: Int {
    guard let length = contextHandle.typedArrayLengthForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard let length = contextHandle.typedArrayByteLengthForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return length
  }

  public var byteOffset: Int {
    guard let offset = contextHandle.typedArrayByteOffsetForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return offset
  }

  public var buffer: JSArrayBuffer<E> {
    guard let bufferHandle = contextHandle.typedArrayBufferForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    return JSArrayBuffer(
      storedValue: JSValue(handleValue: bufferHandle, in: contextHandle),
      contextHandle: contextHandle
    )
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue<E>) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let access = contextHandle.typedArrayBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    let rawBuffer = UnsafeRawBufferPointer(start: start, count: byteLength)
    return body(rawBuffer)
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let access = contextHandle.typedArrayBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    let rawBuffer = UnsafeMutableRawBufferPointer(start: start, count: byteLength)
    return body(rawBuffer)
  }
}

extension JSTypedArray: JSValueEncodable {
  public func toJSValue<TargetEngine: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) -> JSValue<TargetEngine> {
    _ = context
    precondition(
      E.self == TargetEngine.self,
      "Cannot encode JSTypedArray across different JavaScript engine types"
    )

    let handle = unsafeBitCast(value.retainHandle(), to: JSValueHandle<TargetEngine>.self)
    return JSValue(handleValue: handle, in: context.driverContextHandle)
  }

  public func tryEncode<TargetEngine: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) throws(JSValueConversionError) -> JSValue<TargetEngine> {
    toJSValue(in: context)
  }
}

extension JSValue where E: JSEngineTypedArrayDriver {
  public func isArrayBuffer(in context: isolated JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      isArrayBuffer(in: callbackContext)
    }
  }

  public func isArrayBuffer(in context: borrowing JSInstantContext<E>) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(borrowHandle())
  }

  public func typedArrayKind(in context: isolated JSContext<E> = #isolation)
    -> JSTypedArrayKind? where E: JSContextEngine
  {
    context.withInstantContext { callbackContext in
      typedArrayKind(in: callbackContext)
    }
  }

  public func typedArrayKind(in context: borrowing JSInstantContext<E>) -> JSTypedArrayKind? {
    context.driverContextHandle.typedArrayKindForHandle(borrowHandle())
  }

  public func isTypedArray(in context: isolated JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      isTypedArray(in: callbackContext)
    }
  }

  public func isTypedArray(in context: borrowing JSInstantContext<E>) -> Bool {
    typedArrayKind(in: context) != nil
  }
}
