import JavaScriptCore

private let arrayBufferBytesDeallocator: JSTypedArrayBytesDeallocator = { bytes, _ in
  bytes?.deallocate()
}

public struct JSArrayBuffer: ~Copyable {
  let value: JSValue

  init(ref: JSObjectRef, ctx: isolated JSContext = #isolation) {
    self.value = JSValue(ref: ref, ctx: ctx)
  }

  init(ref: JSObjectRef, ctx: borrowing JSCallbackContext) {
    self.value = JSValue(ref: ref, ctx: ctx)
  }

  public init(byteLength: Int, in context: isolated JSContext = #isolation) {
    self = context.withCallbackContext { callbackContext in
      JSArrayBuffer(byteLength: byteLength, in: callbackContext)
    }
  }

  public init(byteLength: Int, in context: borrowing JSCallbackContext) {
    precondition(byteLength >= 0, "ArrayBuffer byteLength must be non-negative")

    var exception: JSValueRef?
    let bytes = Self.allocateZeroedBytes(byteLength: byteLength)
    let ref = JSObjectMakeArrayBufferWithBytesNoCopy(
      context.globalContextRef,
      bytes,
      byteLength,
      arrayBufferBytesDeallocator,
      nil,
      &exception
    )

    guard exception == nil, let ref else {
      arrayBufferBytesDeallocator(bytes, nil)
      preconditionFailure("Failed to create ArrayBuffer")
    }

    self.init(ref: ref, ctx: context)
  }

  public init(copying bytes: [UInt8], in context: isolated JSContext = #isolation) {
    self = context.withCallbackContext { callbackContext in
      JSArrayBuffer(copying: bytes, in: callbackContext)
    }
  }

  public init(copying bytes: [UInt8], in context: borrowing JSCallbackContext) {
    self.init(copying: bytes.withUnsafeBytes { $0 }, in: context)
  }

  public init(copying bytes: UnsafeRawBufferPointer, in context: isolated JSContext = #isolation) {
    self = context.withCallbackContext { callbackContext in
      JSArrayBuffer(copying: bytes, in: callbackContext)
    }
  }

  public init(copying bytes: UnsafeRawBufferPointer, in context: borrowing JSCallbackContext) {
    var exception: JSValueRef?
    let copiedBytes = Self.allocateCopy(of: bytes)
    let ref = JSObjectMakeArrayBufferWithBytesNoCopy(
      context.globalContextRef,
      copiedBytes,
      bytes.count,
      arrayBufferBytesDeallocator,
      nil,
      &exception
    )

    guard exception == nil, let ref else {
      arrayBufferBytesDeallocator(copiedBytes, nil)
      preconditionFailure("Failed to create ArrayBuffer from bytes")
    }

    self.init(ref: ref, ctx: context)
  }

  public init?(value: borrowing JSValue) {
    guard value.isArrayBuffer else {
      return nil
    }

    self.value = JSValue(ref: value.ref, ctx: JSCallbackContext(ctx: value.ctx))
  }

  public var byteLength: Int {
    var exception: JSValueRef?
    let length = JSObjectGetArrayBufferByteLength(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to read ArrayBuffer byteLength")
    return length
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let byteLength = self.byteLength
    var exception: JSValueRef?
    let bytes = JSObjectGetArrayBufferBytesPtr(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to access ArrayBuffer bytes")
    let rawBuffer = UnsafeRawBufferPointer(start: bytes, count: byteLength)
    return body(rawBuffer)
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    var exception: JSValueRef?
    let bytes = JSObjectGetArrayBufferBytesPtr(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to access mutable ArrayBuffer bytes")
    let rawBuffer = UnsafeMutableRawBufferPointer(start: bytes, count: byteLength)
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
  public func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(ref: value.ref, ctx: context)
  }

  public func tryEncode(in context: borrowing JSCallbackContext) throws(JSValueConversionError)
    -> JSValue
  {
    JSValue(ref: value.ref, ctx: context)
  }
}

extension JSValue {
  public var isArrayBuffer: Bool {
    var exception: JSValueRef?
    let type = JSValueGetTypedArrayType(ctx, ref, &exception)
    return exception == nil && type == kJSTypedArrayTypeArrayBuffer
  }
}