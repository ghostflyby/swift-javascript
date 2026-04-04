private let arrayBufferBytesDeallocator: JavaScriptCoreTypedArrayBytesDeallocator = { bytes, _ in
  bytes?.deallocate()
}

extension JSTypedArrayKind {
  var jsType: JavaScriptCoreTypedArrayType {
    switch self {
    case .int8Array:
      return JavaScriptCoreEngine.typedArrayTypeInt8Array
    case .uint8Array:
      return JavaScriptCoreEngine.typedArrayTypeUint8Array
    case .uint8ClampedArray:
      return JavaScriptCoreEngine.typedArrayTypeUint8ClampedArray
    case .int16Array:
      return JavaScriptCoreEngine.typedArrayTypeInt16Array
    case .uint16Array:
      return JavaScriptCoreEngine.typedArrayTypeUint16Array
    case .int32Array:
      return JavaScriptCoreEngine.typedArrayTypeInt32Array
    case .uint32Array:
      return JavaScriptCoreEngine.typedArrayTypeUint32Array
    case .float32Array:
      return JavaScriptCoreEngine.typedArrayTypeFloat32Array
    case .float64Array:
      return JavaScriptCoreEngine.typedArrayTypeFloat64Array
    }
  }

  init?(_ jsType: JavaScriptCoreTypedArrayType) {
    switch jsType {
    case JavaScriptCoreEngine.typedArrayTypeInt8Array:
      self = .int8Array
    case JavaScriptCoreEngine.typedArrayTypeUint8Array:
      self = .uint8Array
    case JavaScriptCoreEngine.typedArrayTypeUint8ClampedArray:
      self = .uint8ClampedArray
    case JavaScriptCoreEngine.typedArrayTypeInt16Array:
      self = .int16Array
    case JavaScriptCoreEngine.typedArrayTypeUint16Array:
      self = .uint16Array
    case JavaScriptCoreEngine.typedArrayTypeInt32Array:
      self = .int32Array
    case JavaScriptCoreEngine.typedArrayTypeUint32Array:
      self = .uint32Array
    case JavaScriptCoreEngine.typedArrayTypeFloat32Array:
      self = .float32Array
    case JavaScriptCoreEngine.typedArrayTypeFloat64Array:
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
    let ref = JavaScriptCoreEngine.makeArrayBufferWithBytesNoCopy(
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
    let ref = JavaScriptCoreEngine.makeArrayBufferWithBytesNoCopy(
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
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
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
      let length = JavaScriptCoreEngine.arrayBufferByteLength(
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
    let access = JavaScriptCoreEngine.arrayBufferBytesPtr(of: value.ref, in: contextRef)
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
    let access = JavaScriptCoreEngine.arrayBufferBytesPtr(of: value.ref, in: contextRef)
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
  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return _asGenericValue(JSValue(ref: value.ref, ctx: jscContext))
  }

  public func tryEncode<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> JSEngineValue<E> {
    toJSValue(in: context)
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

    let ref = JavaScriptCoreEngine.makeTypedArray(
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
      ref = JavaScriptCoreEngine.makeTypedArrayWithArrayBufferAndOffset(
        in: context.globalContextRef,
        type: type.jsType,
        arrayBuffer: bufferRef,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      ref = JavaScriptCoreEngine.makeTypedArrayWithArrayBuffer(
        in: context.globalContextRef,
        type: type.jsType,
        arrayBuffer: bufferRef
      )
    } else {
      let remainingLength = (buffer.byteLength - byteOffset) / type.bytesPerElement
      ref = JavaScriptCoreEngine.makeTypedArrayWithArrayBufferAndOffset(
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
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
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
    guard let length = JavaScriptCoreEngine.typedArrayLength(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard
      let length = JavaScriptCoreEngine.typedArrayByteLength(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return length
  }

  public var byteOffset: Int {
    guard
      let offset = JavaScriptCoreEngine.typedArrayByteOffset(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return offset
  }

  public var buffer: JSArrayBuffer {
    guard let ref = JavaScriptCoreEngine.typedArrayBuffer(of: value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    return JSArrayBuffer(ref: ref, ctx: JSInstantContext(ctx: contextRef))
  }

  public borrowing func withJSValue<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    body(value)
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
    let access = JavaScriptCoreEngine.typedArrayBytesPtr(of: value.ref, in: contextRef)
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
    let access = JavaScriptCoreEngine.typedArrayBytesPtr(of: value.ref, in: contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    let rawBuffer = UnsafeMutableRawBufferPointer(start: start, count: byteLength)
    return body(rawBuffer)
  }
}

extension JSTypedArray: JSValueEncodable {
  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return _asGenericValue(JSValue(ref: value.ref, ctx: jscContext))
  }

  public func tryEncode<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> JSEngineValue<E> {
    toJSValue(in: context)
  }
}

extension JSValue {
  public func isArrayBuffer(in context: isolated JSContext = #isolation) -> Bool {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    return isArrayBuffer(in: callbackContext)
  }

  public func isArrayBuffer(in context: borrowing JSInstantContext) -> Bool {
    guard
      let type = JavaScriptCoreEngine.typedArrayType(of: ref, in: context.globalContextRef)
    else {
      return false
    }
    return type == JavaScriptCoreEngine.typedArrayTypeArrayBuffer
  }

  public func typedArrayKind(in context: isolated JSContext = #isolation) -> JSTypedArrayKind? {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    return typedArrayKind(in: callbackContext)
  }

  public func typedArrayKind(in context: borrowing JSInstantContext) -> JSTypedArrayKind? {
    guard
      let type = JavaScriptCoreEngine.typedArrayType(of: ref, in: context.globalContextRef)
    else {
      return nil
    }
    return JSTypedArrayKind(type)
  }

  public func isTypedArray(in context: isolated JSContext = #isolation) -> Bool {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    return isTypedArray(in: callbackContext)
  }

  public func isTypedArray(in context: borrowing JSInstantContext) -> Bool {
    typedArrayKind(in: context) != nil
  }
}
