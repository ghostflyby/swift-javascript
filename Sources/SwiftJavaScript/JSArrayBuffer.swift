private let arrayBufferBytesDeallocator:
  (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void) = {
    bytes,
    _
    in
    bytes?.deallocate()
  }

public struct JSArrayBuffer<E: JSEngine>: ~Copyable {
  let value: JSEngineValue<E>
  let contextHandle: E.ContextHandle

  package init(storedValue: consuming JSEngineValue<E>, contextHandle: E.ContextHandle) {
    self.value = storedValue
    self.contextHandle = contextHandle
  }

  public init(byteLength: Int, in context: isolated JSEngineContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(byteLength: byteLength, in: callbackContext)
    }
  }

  public init(byteLength: Int, in context: borrowing JSEngineInstantContext<E>) {
    precondition(byteLength >= 0, "ArrayBuffer byteLength must be non-negative")

    let bytes = Self.allocateZeroedBytes(byteLength: byteLength)
    let handle = E.makeArrayBufferWithBytesNoCopyHandle(
      in: context.driverContextHandle,
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: arrayBufferBytesDeallocator,
      deallocatorContext: nil
    )

    guard let handle else {
      arrayBufferBytesDeallocator(bytes, nil)
      preconditionFailure("Failed to create ArrayBuffer")
    }

    self.value = JSEngineValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  public init(copying bytes: [UInt8], in context: isolated JSEngineContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(copying: bytes, in: callbackContext)
    }
  }

  public init(copying bytes: [UInt8], in context: borrowing JSEngineInstantContext<E>) {
    self.init(copying: bytes.withUnsafeBytes { $0 }, in: context)
  }

  public init(
    copying bytes: UnsafeRawBufferPointer,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(copying: bytes, in: callbackContext)
    }
  }

  public init(
    copying bytes: UnsafeRawBufferPointer, in context: borrowing JSEngineInstantContext<E>
  ) {
    let copiedBytes = Self.allocateCopy(of: bytes)
    let handle = E.makeArrayBufferWithBytesNoCopyHandle(
      in: context.driverContextHandle,
      bytes: copiedBytes,
      byteLength: bytes.count,
      bytesDeallocator: arrayBufferBytesDeallocator,
      deallocatorContext: nil
    )

    guard let handle else {
      arrayBufferBytesDeallocator(copiedBytes, nil)
      preconditionFailure("Failed to create ArrayBuffer from bytes")
    }

    self.value = JSEngineValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  public init?(
    value: borrowing JSEngineValue<E>, in context: isolated JSEngineContext<E> = #isolation
  ) {
    guard
      let wrapped = context.withInstantContext({ callbackContext in
        JSArrayBuffer(value: value, in: callbackContext)
      })
    else {
      return nil
    }
    self = wrapped
  }

  public init?(value: borrowing JSEngineValue<E>, in context: borrowing JSEngineInstantContext<E>) {
    guard value.isArrayBuffer(in: context) else {
      return nil
    }

    self.value = JSEngineValue(handleValue: value.valueHandle())
    self.contextHandle = context.driverContextHandle
  }

  public var byteLength: Int {
    guard let length = E.arrayBufferByteLengthForHandle(value.valueHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read ArrayBuffer byteLength")
    }
    return length
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSEngineValue<E>) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let byteLength = self.byteLength
    let access = E.arrayBufferBytesPtrForHandle(value.valueHandle(), in: contextHandle)
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
    let access = E.arrayBufferBytesPtrForHandle(value.valueHandle(), in: contextHandle)
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
  public func toJSValue<TargetEngine: JSEngine>(
    in context: borrowing JSEngineInstantContext<TargetEngine>
  ) -> JSEngineValue<TargetEngine> {
    _ = context
    precondition(
      E.self == TargetEngine.self,
      "Cannot encode JSArrayBuffer across different JavaScript engine types"
    )

    let handle = unsafeBitCast(value.valueHandle(), to: JSValueHandle<TargetEngine>.self)
    return JSEngineValue(handleValue: handle)
  }

  public func tryEncode<TargetEngine: JSEngine>(
    in context: borrowing JSEngineInstantContext<TargetEngine>
  ) throws(JSValueConversionError) -> JSEngineValue<TargetEngine> {
    toJSValue(in: context)
  }
}

public struct JSTypedArray<E: JSEngine>: ~Copyable {
  let value: JSEngineValue<E>
  let contextHandle: E.ContextHandle

  package init(storedValue: consuming JSEngineValue<E>, contextHandle: E.ContextHandle) {
    self.value = storedValue
    self.contextHandle = contextHandle
  }

  public init(
    type: JSTypedArrayKind,
    length: Int,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      JSTypedArray(type: type, length: length, in: callbackContext)
    }
  }

  public init(type: JSTypedArrayKind, length: Int, in context: borrowing JSEngineInstantContext<E>)
  {
    precondition(length >= 0, "TypedArray length must be non-negative")

    guard
      let handle = E.makeTypedArrayHandle(
        in: context.driverContextHandle,
        kind: type,
        length: length
      )
    else {
      preconditionFailure("Failed to create TypedArray")
    }

    self.value = JSEngineValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  public init(
    type: JSTypedArrayKind,
    buffer: borrowing JSArrayBuffer<E>,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      JSTypedArray(
        type: type,
        buffer: buffer,
        byteOffset: byteOffset,
        length: length,
        in: callbackContext
      )
    }
  }

  public init(
    type: JSTypedArrayKind,
    buffer: borrowing JSArrayBuffer<E>,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    let handle: JSValueHandle<E>?
    let bufferHandle = buffer.value.valueHandle()

    if let length {
      handle = E.makeTypedArrayHandle(
        in: context.driverContextHandle,
        kind: type,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      handle = E.makeTypedArrayHandle(
        in: context.driverContextHandle,
        kind: type,
        arrayBuffer: bufferHandle
      )
    } else {
      let remainingLength = (buffer.byteLength - byteOffset) / type.bytesPerElement
      handle = E.makeTypedArrayHandle(
        in: context.driverContextHandle,
        kind: type,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: remainingLength
      )
    }

    guard let handle else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }

    self.value = JSEngineValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  public init?(
    value: borrowing JSEngineValue<E>, in context: isolated JSEngineContext<E> = #isolation
  ) {
    guard
      let wrapped = context.withInstantContext({ callbackContext in
        JSTypedArray(value: value, in: callbackContext)
      })
    else {
      return nil
    }
    self = wrapped
  }

  public init?(value: borrowing JSEngineValue<E>, in context: borrowing JSEngineInstantContext<E>) {
    guard value.typedArrayKind(in: context) != nil else {
      return nil
    }

    self.value = JSEngineValue(handleValue: value.valueHandle())
    self.contextHandle = context.driverContextHandle
  }

  public var kind: JSTypedArrayKind {
    guard let type = E.typedArrayKindForHandle(value.valueHandle(), in: contextHandle) else {
      preconditionFailure("Wrapped JSEngineValue is not a TypedArray")
    }
    return type
  }

  public var length: Int {
    guard let length = E.typedArrayLengthForHandle(value.valueHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard let length = E.typedArrayByteLengthForHandle(value.valueHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return length
  }

  public var byteOffset: Int {
    guard let offset = E.typedArrayByteOffsetForHandle(value.valueHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return offset
  }

  public var buffer: JSArrayBuffer<E> {
    guard let bufferHandle = E.typedArrayBufferForHandle(value.valueHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    return JSArrayBuffer(
      storedValue: JSEngineValue(handleValue: bufferHandle),
      contextHandle: contextHandle
    )
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSEngineValue<E>) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let access = E.typedArrayBytesPtrForHandle(value.valueHandle(), in: contextHandle)
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
    let access = E.typedArrayBytesPtrForHandle(value.valueHandle(), in: contextHandle)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    let rawBuffer = UnsafeMutableRawBufferPointer(start: start, count: byteLength)
    return body(rawBuffer)
  }
}

extension JSTypedArray: JSValueEncodable {
  public func toJSValue<TargetEngine: JSEngine>(
    in context: borrowing JSEngineInstantContext<TargetEngine>
  ) -> JSEngineValue<TargetEngine> {
    _ = context
    precondition(
      E.self == TargetEngine.self,
      "Cannot encode JSTypedArray across different JavaScript engine types"
    )

    let handle = unsafeBitCast(value.valueHandle(), to: JSValueHandle<TargetEngine>.self)
    return JSEngineValue(handleValue: handle)
  }

  public func tryEncode<TargetEngine: JSEngine>(
    in context: borrowing JSEngineInstantContext<TargetEngine>
  ) throws(JSValueConversionError) -> JSEngineValue<TargetEngine> {
    toJSValue(in: context)
  }
}

extension JSEngineValue {
  public func isArrayBuffer(in context: isolated JSEngineContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArrayBuffer(in: callbackContext)
    }
  }

  public func isArrayBuffer(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    E.isArrayBufferHandle(valueHandle(), in: context.driverContextHandle)
  }

  public func typedArrayKind(in context: isolated JSEngineContext<E> = #isolation)
    -> JSTypedArrayKind?
  {
    context.withInstantContext { callbackContext in
      typedArrayKind(in: callbackContext)
    }
  }

  public func typedArrayKind(in context: borrowing JSEngineInstantContext<E>) -> JSTypedArrayKind? {
    E.typedArrayKindForHandle(valueHandle(), in: context.driverContextHandle)
  }

  public func isTypedArray(in context: isolated JSEngineContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isTypedArray(in: callbackContext)
    }
  }

  public func isTypedArray(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    typedArrayKind(in: context) != nil
  }
}
