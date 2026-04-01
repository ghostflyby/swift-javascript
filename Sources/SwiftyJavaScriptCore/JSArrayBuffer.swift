private let arrayBufferBytesDeallocator: JavaScriptCoreTypedArrayBytesDeallocator = { bytes, _ in
  bytes?.deallocate()
}

extension JSTypedArrayKind {
  var jsType: JavaScriptCoreTypedArrayType {
    switch self {
    case .int8Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeInt8Array
    case .uint8Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeUint8Array
    case .uint8ClampedArray:
      return JavaScriptCoreBackendDriver.typedArrayTypeUint8ClampedArray
    case .int16Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeInt16Array
    case .uint16Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeUint16Array
    case .int32Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeInt32Array
    case .uint32Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeUint32Array
    case .float32Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeFloat32Array
    case .float64Array:
      return JavaScriptCoreBackendDriver.typedArrayTypeFloat64Array
    }
  }

  init?(_ jsType: JavaScriptCoreTypedArrayType) {
    switch jsType {
    case JavaScriptCoreBackendDriver.typedArrayTypeInt8Array:
      self = .int8Array
    case JavaScriptCoreBackendDriver.typedArrayTypeUint8Array:
      self = .uint8Array
    case JavaScriptCoreBackendDriver.typedArrayTypeUint8ClampedArray:
      self = .uint8ClampedArray
    case JavaScriptCoreBackendDriver.typedArrayTypeInt16Array:
      self = .int16Array
    case JavaScriptCoreBackendDriver.typedArrayTypeUint16Array:
      self = .uint16Array
    case JavaScriptCoreBackendDriver.typedArrayTypeInt32Array:
      self = .int32Array
    case JavaScriptCoreBackendDriver.typedArrayTypeUint32Array:
      self = .uint32Array
    case JavaScriptCoreBackendDriver.typedArrayTypeFloat32Array:
      self = .float32Array
    case JavaScriptCoreBackendDriver.typedArrayTypeFloat64Array:
      self = .float64Array
    default:
      return nil
    }
  }
}

public struct JSArrayBuffer: ~Copyable {
  let value: JSValue
  let contextRef: JavaScriptCoreContextRef

  init(ref: JavaScriptCoreObjectRef, ctx: isolated JSContext = #isolation) {
    self.value = JSValue(ref: ref, ctx: ctx)
    self.contextRef = ctx.globalContextRef
  }

  init(ref: JavaScriptCoreObjectRef, ctx: borrowing JSInstantContext) {
    self.value = JSValue(ref: ref, ctx: ctx)
    self.contextRef = ctx.globalContextRef
  }

  public init(byteLength: Int, in context: isolated JSContext = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSArrayBuffer(byteLength: byteLength, in: callbackContext)
    }
  }

  public init(byteLength: Int, in context: borrowing JSInstantContext) {
    precondition(byteLength >= 0, "ArrayBuffer byteLength must be non-negative")

    let bytes = Self.allocateZeroedBytes(byteLength: byteLength)
    let ref = JavaScriptCoreBackendDriver.makeArrayBufferWithBytesNoCopy(
      in: context.globalContextRef,
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: arrayBufferBytesDeallocator,
      deallocatorContext: nil
    )

    guard let ref else {
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
    let copiedBytes = Self.allocateCopy(of: bytes)
    let ref = JavaScriptCoreBackendDriver.makeArrayBufferWithBytesNoCopy(
      in: context.globalContextRef,
      bytes: copiedBytes,
      byteLength: bytes.count,
      bytesDeallocator: arrayBufferBytesDeallocator,
      deallocatorContext: nil
    )

    guard let ref else {
      arrayBufferBytesDeallocator(copiedBytes, nil)
      preconditionFailure("Failed to create ArrayBuffer from bytes")
    }

    self.init(ref: ref, ctx: context)
  }

  public init?(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(value: value, in: callbackContext)
  }

  public init?(value: borrowing JSValue, in context: borrowing JSInstantContext) {
    guard value.isArrayBuffer(in: context) else {
      return nil
    }

    self.value = JSValue(ref: value.ref, ctx: context)
    self.contextRef = context.globalContextRef
  }

  public var byteLength: Int {
    guard
      let length = JavaScriptCoreBackendDriver.arrayBufferByteLength(
        of: value.ref,
        in: contextRef
      )
    else {
      preconditionFailure("Failed to read ArrayBuffer byteLength")
    }
    return length
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let byteLength = self.byteLength
    let access = JavaScriptCoreBackendDriver.arrayBufferBytesPtr(of: value.ref, in: contextRef)
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
    let access = JavaScriptCoreBackendDriver.arrayBufferBytesPtr(of: value.ref, in: contextRef)
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
  let contextRef: JavaScriptCoreContextRef

  init(ref: JavaScriptCoreObjectRef, ctx: isolated JSContext = #isolation) {
    self.value = JSValue(ref: ref, ctx: ctx)
    self.contextRef = ctx.globalContextRef
  }

  init(ref: JavaScriptCoreObjectRef, ctx: borrowing JSInstantContext) {
    self.value = JSValue(ref: ref, ctx: ctx)
    self.contextRef = ctx.globalContextRef
  }

  public init(type: JSTypedArrayKind, length: Int, in context: isolated JSContext = #isolation) {
    self = context.withInstantContext { callbackContext in
      JSTypedArray(type: type, length: length, in: callbackContext)
    }
  }

  public init(type: JSTypedArrayKind, length: Int, in context: borrowing JSInstantContext) {
    precondition(length >= 0, "TypedArray length must be non-negative")

    let ref = JavaScriptCoreBackendDriver.makeTypedArray(
      in: context.globalContextRef,
      type: type.jsType,
      length: length
    )

    guard let ref else {
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

    let ref: JavaScriptCoreObjectRef?
    let bufferRef = buffer.value.ref

    if let length {
      ref = JavaScriptCoreBackendDriver.makeTypedArrayWithArrayBufferAndOffset(
        in: context.globalContextRef,
        type: type.jsType,
        arrayBuffer: bufferRef,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      ref = JavaScriptCoreBackendDriver.makeTypedArrayWithArrayBuffer(
        in: context.globalContextRef,
        type: type.jsType,
        arrayBuffer: bufferRef
      )
    } else {
      let remainingLength = (buffer.byteLength - byteOffset) / type.bytesPerElement
      ref = JavaScriptCoreBackendDriver.makeTypedArrayWithArrayBufferAndOffset(
        in: context.globalContextRef,
        type: type.jsType,
        arrayBuffer: bufferRef,
        byteOffset: byteOffset,
        length: remainingLength
      )
    }

    guard let ref else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }

    self.init(ref: ref, ctx: context)
  }

  public init?(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(value: value, in: callbackContext)
  }

  public init?(value: borrowing JSValue, in context: borrowing JSInstantContext) {
    guard value.typedArrayKind(in: context) != nil else {
      return nil
    }

    self.value = JSValue(ref: value.ref, ctx: context)
    self.contextRef = context.globalContextRef
  }

  public var kind: JSTypedArrayKind {
    let type = value.typedArrayKind(in: JSInstantContext(ctx: contextRef))
    precondition(type != nil, "Wrapped JSValue is not a TypedArray")
    return type!
  }

  public var length: Int {
    guard let length = JavaScriptCoreBackendDriver.typedArrayLength(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard
      let length = JavaScriptCoreBackendDriver.typedArrayByteLength(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return length
  }

  public var byteOffset: Int {
    guard
      let offset = JavaScriptCoreBackendDriver.typedArrayByteOffset(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return offset
  }

  public var buffer: JSArrayBuffer {
    guard let ref = JavaScriptCoreBackendDriver.typedArrayBuffer(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    return JSArrayBuffer(ref: ref, ctx: JSInstantContext(ctx: contextRef))
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let access = JavaScriptCoreBackendDriver.typedArrayBytesPtr(of: value.ref, in: contextRef)
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
    let access = JavaScriptCoreBackendDriver.typedArrayBytesPtr(of: value.ref, in: contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    let rawBuffer = UnsafeMutableRawBufferPointer(start: start, count: byteLength)
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
  public func isArrayBuffer(in context: isolated JSContext = #isolation) -> Bool {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return isArrayBuffer(in: callbackContext)
  }

  public func isArrayBuffer(in context: borrowing JSInstantContext) -> Bool {
    guard
      let type = JavaScriptCoreBackendDriver.typedArrayType(of: ref, in: context.globalContextRef)
    else {
      return false
    }
    return type == JavaScriptCoreBackendDriver.typedArrayTypeArrayBuffer
  }

  public func typedArrayKind(in context: isolated JSContext = #isolation) -> JSTypedArrayKind? {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return typedArrayKind(in: callbackContext)
  }

  public func typedArrayKind(in context: borrowing JSInstantContext) -> JSTypedArrayKind? {
    guard
      let type = JavaScriptCoreBackendDriver.typedArrayType(of: ref, in: context.globalContextRef)
    else {
      return nil
    }
    return JSTypedArrayKind(type)
  }

  public func isTypedArray(in context: isolated JSContext = #isolation) -> Bool {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return isTypedArray(in: callbackContext)
  }

  public func isTypedArray(in context: borrowing JSInstantContext) -> Bool {
    typedArrayKind(in: context) != nil
  }
}
