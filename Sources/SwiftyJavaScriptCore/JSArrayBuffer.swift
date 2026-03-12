import JavaScriptCore

private let arrayBufferBytesDeallocator: JSTypedArrayBytesDeallocator = { bytes, _ in
  bytes?.deallocate()
}

public enum JSTypedArrayKind: Sendable, Hashable {
  case int8Array
  case uint8Array
  case uint8ClampedArray
  case int16Array
  case uint16Array
  case int32Array
  case uint32Array
  case float32Array
  case float64Array

  var jsType: JSTypedArrayType {
    switch self {
    case .int8Array:
      return kJSTypedArrayTypeInt8Array
    case .uint8Array:
      return kJSTypedArrayTypeUint8Array
    case .uint8ClampedArray:
      return kJSTypedArrayTypeUint8ClampedArray
    case .int16Array:
      return kJSTypedArrayTypeInt16Array
    case .uint16Array:
      return kJSTypedArrayTypeUint16Array
    case .int32Array:
      return kJSTypedArrayTypeInt32Array
    case .uint32Array:
      return kJSTypedArrayTypeUint32Array
    case .float32Array:
      return kJSTypedArrayTypeFloat32Array
    case .float64Array:
      return kJSTypedArrayTypeFloat64Array
    }
  }

  init?(_ jsType: JSTypedArrayType) {
    switch jsType {
    case kJSTypedArrayTypeInt8Array:
      self = .int8Array
    case kJSTypedArrayTypeUint8Array:
      self = .uint8Array
    case kJSTypedArrayTypeUint8ClampedArray:
      self = .uint8ClampedArray
    case kJSTypedArrayTypeInt16Array:
      self = .int16Array
    case kJSTypedArrayTypeUint16Array:
      self = .uint16Array
    case kJSTypedArrayTypeInt32Array:
      self = .int32Array
    case kJSTypedArrayTypeUint32Array:
      self = .uint32Array
    case kJSTypedArrayTypeFloat32Array:
      self = .float32Array
    case kJSTypedArrayTypeFloat64Array:
      self = .float64Array
    default:
      return nil
    }
  }

  public var bytesPerElement: Int {
    switch self {
    case .int8Array, .uint8Array, .uint8ClampedArray:
      return 1
    case .int16Array, .uint16Array:
      return 2
    case .int32Array, .uint32Array, .float32Array:
      return 4
    case .float64Array:
      return 8
    }
  }
}

public struct JSArrayBuffer: ~Copyable {
  let value: JSValue

  init(ref: JSObjectRef, ctx: isolated JSContext = #isolation) {
    self.value = JSValue(ref: ref, ctx: ctx)
  }

  init(ref: JSObjectRef, ctx: borrowing JSInstantContext) {
    self.value = JSValue(ref: ref, ctx: ctx)
  }

  public init(byteLength: Int, in context: isolated JSContext = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(byteLength: byteLength, in: callbackContext)
    }
  }

  public init(byteLength: Int, in context: borrowing JSInstantContext) {
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
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(copying: bytes, in: callbackContext)
    }
  }

  public init(copying bytes: [UInt8], in context: borrowing JSInstantContext) {
    self.init(copying: bytes.withUnsafeBytes { $0 }, in: context)
  }

  public init(copying bytes: UnsafeRawBufferPointer, in context: isolated JSContext = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(copying: bytes, in: callbackContext)
    }
  }

  public init(copying bytes: UnsafeRawBufferPointer, in context: borrowing JSInstantContext) {
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

    self.value = JSValue(ref: value.ref, ctx: JSInstantContext(ctx: value.ctx))
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
  public func toJSValue(in context: borrowing JSInstantContext) -> JSValue {
    JSValue(ref: value.ref, ctx: context)
  }

  public func tryEncode(in context: borrowing JSInstantContext) throws(JSValueConversionError)
    -> JSValue
  {
    JSValue(ref: value.ref, ctx: context)
  }
}

public struct JSTypedArray: ~Copyable {
  let value: JSValue

  init(ref: JSObjectRef, ctx: isolated JSContext = #isolation) {
    self.value = JSValue(ref: ref, ctx: ctx)
  }

  init(ref: JSObjectRef, ctx: borrowing JSInstantContext) {
    self.value = JSValue(ref: ref, ctx: ctx)
  }

  public init(type: JSTypedArrayKind, length: Int, in context: isolated JSContext = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSTypedArray(type: type, length: length, in: callbackContext)
    }
  }

  public init(type: JSTypedArrayKind, length: Int, in context: borrowing JSInstantContext) {
    precondition(length >= 0, "TypedArray length must be non-negative")

    var exception: JSValueRef?
    let ref = JSObjectMakeTypedArray(
      context.globalContextRef,
      type.jsType,
      length,
      &exception
    )

    guard exception == nil, let ref else {
      preconditionFailure("Failed to create TypedArray")
    }

    self.init(ref: ref, ctx: context)
  }

  public init(
    type: JSTypedArrayKind,
    buffer: borrowing JSArrayBuffer,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: isolated JSContext = #isolation
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
    buffer: borrowing JSArrayBuffer,
    byteOffset: Int = 0,
    length: Int? = nil,
    in context: borrowing JSInstantContext
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    var exception: JSValueRef?
    let ref: JSObjectRef?
    let bufferRef = buffer.value.ref

    if let length {
      ref = JSObjectMakeTypedArrayWithArrayBufferAndOffset(
        context.globalContextRef,
        type.jsType,
        bufferRef,
        byteOffset,
        length,
        &exception
      )
    } else if byteOffset == 0 {
      ref = JSObjectMakeTypedArrayWithArrayBuffer(
        context.globalContextRef,
        type.jsType,
        bufferRef,
        &exception
      )
    } else {
      let remainingLength = (buffer.byteLength - byteOffset) / type.bytesPerElement
      ref = JSObjectMakeTypedArrayWithArrayBufferAndOffset(
        context.globalContextRef,
        type.jsType,
        bufferRef,
        byteOffset,
        remainingLength,
        &exception
      )
    }

    guard exception == nil, let ref else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }

    self.init(ref: ref, ctx: context)
  }

  public init?(value: borrowing JSValue) {
    guard value.typedArrayKind != nil else {
      return nil
    }

    self.value = JSValue(ref: value.ref, ctx: JSInstantContext(ctx: value.ctx))
  }

  public var kind: JSTypedArrayKind {
    let type = value.typedArrayKind
    precondition(type != nil, "Wrapped JSValue is not a TypedArray")
    return type!
  }

  public var length: Int {
    var exception: JSValueRef?
    let length = JSObjectGetTypedArrayLength(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to read TypedArray length")
    return length
  }

  public var byteLength: Int {
    var exception: JSValueRef?
    let length = JSObjectGetTypedArrayByteLength(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to read TypedArray byteLength")
    return length
  }

  public var byteOffset: Int {
    var exception: JSValueRef?
    let offset = JSObjectGetTypedArrayByteOffset(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to read TypedArray byteOffset")
    return offset
  }

  public var buffer: JSArrayBuffer {
    var exception: JSValueRef?
    let ref = JSObjectGetTypedArrayBuffer(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to read TypedArray buffer")
    return JSArrayBuffer(ref: ref!, ctx: JSInstantContext(ctx: value.ctx))
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    var exception: JSValueRef?
    let bytes = JSObjectGetTypedArrayBytesPtr(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to access TypedArray bytes")
    let rawBuffer = UnsafeRawBufferPointer(start: bytes, count: byteLength)
    return body(rawBuffer)
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    var exception: JSValueRef?
    let bytes = JSObjectGetTypedArrayBytesPtr(value.ctx, value.ref, &exception)
    precondition(exception == nil, "Failed to access mutable TypedArray bytes")
    let rawBuffer = UnsafeMutableRawBufferPointer(start: bytes, count: byteLength)
    return body(rawBuffer)
  }
}

extension JSTypedArray: JSValueEncodable {
  public func toJSValue(in context: borrowing JSInstantContext) -> JSValue {
    JSValue(ref: value.ref, ctx: context)
  }

  public func tryEncode(in context: borrowing JSInstantContext) throws(JSValueConversionError)
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

  public var typedArrayKind: JSTypedArrayKind? {
    var exception: JSValueRef?
    let type = JSValueGetTypedArrayType(ctx, ref, &exception)
    guard exception == nil else {
      return nil
    }
    return JSTypedArrayKind(type)
  }

  public var isTypedArray: Bool {
    typedArrayKind != nil
  }
}
