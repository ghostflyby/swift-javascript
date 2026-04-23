private let arrayBufferBytesDeallocator:
  (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void) = {
    bytes,
    _
    in
    bytes?.deallocate()
  }

public struct JSArrayBuffer<E: JSEngine>: ~Copyable, ~Escapable {
  let value: JSValue<E>
  let contextHandle: E.ContextHandle

  @_lifetime(copy storedValue)
  package init(storedValue: consuming JSValue<E>, contextHandle: E.ContextHandle) {
    self.value = storedValue
    self.contextHandle = contextHandle
  }

  @_lifetime(borrow context)
  public init(byteLength: Int, in context: borrowing isolated JSContext<E> = #isolation) {
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init(byteLength: Int, in context: borrowing JSInstantContext<E>) {
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init(copying bytes: [UInt8], in context: borrowing isolated JSContext<E> = #isolation) {
    self.init(copying: bytes.withUnsafeBytes { $0 }, in: context)
  }

  @_lifetime(borrow context)
  public init(copying bytes: [UInt8], in context: borrowing JSInstantContext<E>) {
    self.init(copying: bytes.withUnsafeBytes { $0 }, in: context)
  }

  @_lifetime(borrow context)
  public init(
    copying bytes: UnsafeRawBufferPointer,
    in context: borrowing isolated JSContext<E> = #isolation
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init(
    copying bytes: UnsafeRawBufferPointer, in context: borrowing JSInstantContext<E>
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init?(
    value: borrowing JSValue<E>, in context: borrowing isolated JSContext<E> = #isolation
  ) {
    guard E.isArrayBufferHandle(value.borrowHandle(), in: context.driverContextHandle) else {
      return nil
    }

    self.value = JSValue(retaining: value)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init?(value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>) {
    guard value.isArrayBuffer(in: context) else {
      return nil
    }

    self.value = JSValue(retaining: value)
    self.contextHandle = context.driverContextHandle
  }

  public var byteLength: Int {
    guard let length = E.arrayBufferByteLengthForHandle(value.borrowHandle(), in: contextHandle)
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
    let access = E.arrayBufferBytesPtrForHandle(value.borrowHandle(), in: contextHandle)
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
    let access = E.arrayBufferBytesPtrForHandle(value.borrowHandle(), in: contextHandle)
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
  @_lifetime(borrow context)
  public func toJSValue<TargetEngine: JSEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) -> JSValue<TargetEngine> {
    _ = context
    precondition(
      E.self == TargetEngine.self,
      "Cannot encode JSArrayBuffer across different JavaScript engine types"
    )

    let handle = unsafeBitCast(value.retainHandle(), to: JSValueHandle<TargetEngine>.self)
    return JSValue(handleValue: handle)
  }

  @_lifetime(borrow context)
  public func tryEncode<TargetEngine: JSEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) throws(JSValueConversionError) -> JSValue<TargetEngine> {
    toJSValue(in: context)
  }
}

public struct JSTypedArray<E: JSEngine>: ~Copyable, ~Escapable {
  let value: JSValue<E>
  let contextHandle: E.ContextHandle

  @_lifetime(copy storedValue)
  package init(storedValue: consuming JSValue<E>, contextHandle: E.ContextHandle) {
    self.value = storedValue
    self.contextHandle = contextHandle
  }

  @_lifetime(borrow context)
  public init(
    type: JSTypedArrayKind,
    length: Int,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init(type: JSTypedArrayKind, length: Int, in context: borrowing JSInstantContext<E>) {
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init(
    type: JSTypedArrayKind,
    buffer: borrowing JSArrayBuffer<E>,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    let handle: JSValueHandle<E>?
    let bufferHandle = buffer.value.borrowHandle()

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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
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

    self.value = JSValue(handleValue: handle)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init?(
    value: borrowing JSValue<E>, in context: borrowing isolated JSContext<E> = #isolation
  ) {
    guard E.typedArrayKindForHandle(value.borrowHandle(), in: context.driverContextHandle) != nil
    else {
      return nil
    }

    self.value = JSValue(retaining: value)
    self.contextHandle = context.driverContextHandle
  }

  @_lifetime(borrow context)
  public init?(value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>) {
    guard value.typedArrayKind(in: context) != nil else {
      return nil
    }

    self.value = JSValue(retaining: value)
    self.contextHandle = context.driverContextHandle
  }

  public var kind: JSTypedArrayKind {
    guard let type = E.typedArrayKindForHandle(value.borrowHandle(), in: contextHandle) else {
      preconditionFailure("Wrapped JSValue is not a TypedArray")
    }
    return type
  }

  public var length: Int {
    guard let length = E.typedArrayLengthForHandle(value.borrowHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard let length = E.typedArrayByteLengthForHandle(value.borrowHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return length
  }

  public var byteOffset: Int {
    guard let offset = E.typedArrayByteOffsetForHandle(value.borrowHandle(), in: contextHandle)
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return offset
  }

  public var buffer: JSArrayBuffer<E> {
    @_lifetime(borrow self)
    get {
      guard let bufferHandle = E.typedArrayBufferForHandle(value.borrowHandle(), in: contextHandle)
      else {
        preconditionFailure("Failed to read TypedArray buffer")
      }
      return JSArrayBuffer(
        storedValue: JSValue(handleValue: bufferHandle),
        contextHandle: contextHandle
      )
    }
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue<E>) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let access = E.typedArrayBytesPtrForHandle(value.borrowHandle(), in: contextHandle)
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
    let access = E.typedArrayBytesPtrForHandle(value.borrowHandle(), in: contextHandle)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    let rawBuffer = UnsafeMutableRawBufferPointer(start: start, count: byteLength)
    return body(rawBuffer)
  }
}

extension JSTypedArray: JSValueEncodable {
  @_lifetime(borrow context)
  public func toJSValue<TargetEngine: JSEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) -> JSValue<TargetEngine> {
    _ = context
    precondition(
      E.self == TargetEngine.self,
      "Cannot encode JSTypedArray across different JavaScript engine types"
    )

    let handle = unsafeBitCast(value.retainHandle(), to: JSValueHandle<TargetEngine>.self)
    return JSValue(handleValue: handle)
  }

  @_lifetime(borrow context)
  public func tryEncode<TargetEngine: JSEngine>(
    in context: borrowing JSInstantContext<TargetEngine>
  ) throws(JSValueConversionError) -> JSValue<TargetEngine> {
    toJSValue(in: context)
  }
}

extension JSValue {
  public func isArrayBuffer(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArrayBuffer(in: callbackContext)
    }
  }

  public func isArrayBuffer(in context: borrowing JSInstantContext<E>) -> Bool {
    E.isArrayBufferHandle(borrowHandle(), in: context.driverContextHandle)
  }

  public func typedArrayKind(in context: borrowing isolated JSContext<E> = #isolation)
    -> JSTypedArrayKind?
  {
    context.withInstantContext { callbackContext in
      typedArrayKind(in: callbackContext)
    }
  }

  public func typedArrayKind(in context: borrowing JSInstantContext<E>) -> JSTypedArrayKind? {
    E.typedArrayKindForHandle(borrowHandle(), in: context.driverContextHandle)
  }

  public func isTypedArray(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isTypedArray(in: callbackContext)
    }
  }

  public func isTypedArray(in context: borrowing JSInstantContext<E>) -> Bool {
    typedArrayKind(in: context) != nil
  }
}
