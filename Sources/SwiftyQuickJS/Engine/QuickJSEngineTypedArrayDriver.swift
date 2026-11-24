import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QJSEngine: JSEngineTypedArrayDriver {
  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: QJSContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> QJSValueHandle? {
    let opaque: UnsafeMutableRawPointer? =
      if let bytesDeallocator {
        Unmanaged.passRetained(
          QuickJSArrayBufferDeallocatorBox(
            deallocator: bytesDeallocator,
            context: deallocatorContext
          )
        ).toOpaque()
      } else {
        nil
      }
    let value = JS_NewArrayBuffer(
      context.ref,
      bytes?.assumingMemoryBound(to: UInt8.self),
      byteLength,
      quickJSArrayBufferFree,
      opaque,
      false
    )
    if JS_IsException(value) {
      quickJSClearPendingException(in: context)
      if let opaque {
        _ = Unmanaged<QuickJSArrayBufferDeallocatorBox>.fromOpaque(opaque).takeRetainedValue()
      }
      return nil
    }
    return QJSValueHandle(ref: value)
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Int? {
    var size = 0
    guard JS_GetArrayBuffer(context.ref, &size, value.ref) != nil else {
      return nil
    }
    return size
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var size = 0
    let bytes = JS_GetArrayBuffer(context.ref, &size, value.ref)
    return (UnsafeMutableRawPointer(bytes), bytes == nil)
  }

  public static func makeTypedArrayHandle(
    in context: QJSContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> QJSValueHandle? {
    var arguments = [JS_NewFloat64(context.ref, Double(length))]
    return quickJSMakeTypedArrayHandle(in: context, kind: kind, arguments: &arguments)
  }

  public static func makeTypedArrayHandle(
    in context: QJSContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: QJSValueHandle
  ) -> QJSValueHandle? {
    var arguments = [
      arrayBuffer.ref,
      JS_NewFloat64(context.ref, 0),
      quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED)),
    ]
    return quickJSMakeTypedArrayHandle(in: context, kind: kind, arguments: &arguments)
  }

  public static func makeTypedArrayHandle(
    in context: QJSContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: QJSValueHandle,
    byteOffset: Int,
    length: Int
  ) -> QJSValueHandle? {
    var arguments = [
      arrayBuffer.ref,
      JS_NewFloat64(context.ref, Double(byteOffset)),
      JS_NewFloat64(context.ref, Double(length)),
    ]
    return quickJSMakeTypedArrayHandle(in: context, kind: kind, arguments: &arguments)
  }

  public static func typedArrayLengthForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Int? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context.ref, buffer)
    guard bytesPerElement > 0 else {
      return nil
    }
    return byteLength / bytesPerElement
  }

  public static func typedArrayByteLengthForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Int? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context.ref, buffer)
    return byteLength
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Int? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context.ref, buffer)
    return byteOffset
  }

  public static func typedArrayBufferForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> QJSValueHandle? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    return QJSValueHandle(ref: buffer)
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return (nil, true)
    }
    defer { JS_FreeValue(context.ref, buffer) }
    return arrayBufferBytesPtrForHandle(
      QJSValueHandle(ref: buffer),
      in: context
    )
  }

  public static func isArrayBufferHandle(
    _ value: QJSValueHandle,
    in _: QJSContextHandle
  ) -> Bool {
    JS_IsArrayBuffer(value.ref)
  }

  public static func typedArrayKindForHandle(
    _ value: QJSValueHandle,
    in _: QJSContextHandle
  ) -> JSTypedArrayKind? {
    switch JS_GetTypedArrayType(value.ref) {
    case 1:
      return .int8Array
    case 2:
      return .uint8Array
    case 0:
      return .uint8ClampedArray
    case 3:
      return .int16Array
    case 4:
      return .uint16Array
    case 5:
      return .int32Array
    case 6:
      return .uint32Array
    case 10:
      return .float32Array
    case 11:
      return .float64Array
    default:
      return nil
    }
  }
}

private func quickJSMakeTypedArrayHandle(
  in context: QJSContextHandle,
  kind: JSTypedArrayKind,
  arguments: inout [CQuickJSValue]
) -> QJSValueHandle? {
  let value = arguments.withUnsafeMutableBufferPointer { buffer in
    JS_NewTypedArray(
      context.ref,
      Int32(buffer.count),
      buffer.baseAddress,
      quickJSTypedArrayType(for: kind)
    )
  }
  guard !JS_IsException(value) else {
    quickJSClearPendingException(in: context)
    return nil
  }
  return QJSValueHandle(ref: value)
}

private func quickJSClearPendingException(in context: QJSContextHandle) {
  let exception = JS_GetException(context.ref)
  JS_FreeValue(context.ref, exception)
}

private func quickJSTypedArrayType(for kind: JSTypedArrayKind) -> JSTypedArrayEnum {
  switch kind {
  case .int8Array:
    return JS_TYPED_ARRAY_INT8
  case .uint8Array:
    return JS_TYPED_ARRAY_UINT8
  case .uint8ClampedArray:
    return JS_TYPED_ARRAY_UINT8C
  case .int16Array:
    return JS_TYPED_ARRAY_INT16
  case .uint16Array:
    return JS_TYPED_ARRAY_UINT16
  case .int32Array:
    return JS_TYPED_ARRAY_INT32
  case .uint32Array:
    return JS_TYPED_ARRAY_UINT32
  case .float32Array:
    return JS_TYPED_ARRAY_FLOAT32
  case .float64Array:
    return JS_TYPED_ARRAY_FLOAT64
  }
}

private func quickJSArrayBufferFree(
  _: OpaquePointer?,
  opaque: UnsafeMutableRawPointer?,
  ptr: UnsafeMutableRawPointer?
) {
  guard let opaque else {
    return
  }
  let box = Unmanaged<QuickJSArrayBufferDeallocatorBox>.fromOpaque(opaque).takeRetainedValue()
  box.deallocator(ptr, box.context)
}

// MARK: - Context-side driver conformance (Stage 2B)

extension QJSContextHandle: JSContextTypedArrayDriver {
  public func makeArrayBufferWithBytesNoCopyHandle(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> QJSValueHandle? {
    QJSEngine.makeArrayBufferWithBytesNoCopyHandle(
      in: self,
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: bytesDeallocator,
      deallocatorContext: deallocatorContext
    )
  }

  public func arrayBufferByteLengthForHandle(_ value: QJSValueHandle) -> Int? {
    QJSEngine.arrayBufferByteLengthForHandle(value, in: self)
  }

  public func arrayBufferBytesPtrForHandle(
    _ value: QJSValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    QJSEngine.arrayBufferBytesPtrForHandle(value, in: self)
  }

  public func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    length: Int
  ) -> QJSValueHandle? {
    QJSEngine.makeTypedArrayHandle(in: self, kind: kind, length: length)
  }

  public func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: QJSValueHandle
  ) -> QJSValueHandle? {
    QJSEngine.makeTypedArrayHandle(in: self, kind: kind, arrayBuffer: arrayBuffer)
  }

  public func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: QJSValueHandle,
    byteOffset: Int,
    length: Int
  ) -> QJSValueHandle? {
    QJSEngine.makeTypedArrayHandle(
      in: self,
      kind: kind,
      arrayBuffer: arrayBuffer,
      byteOffset: byteOffset,
      length: length
    )
  }

  public func typedArrayLengthForHandle(_ value: QJSValueHandle) -> Int? {
    QJSEngine.typedArrayLengthForHandle(value, in: self)
  }

  public func typedArrayByteLengthForHandle(_ value: QJSValueHandle) -> Int? {
    QJSEngine.typedArrayByteLengthForHandle(value, in: self)
  }

  public func typedArrayByteOffsetForHandle(_ value: QJSValueHandle) -> Int? {
    QJSEngine.typedArrayByteOffsetForHandle(value, in: self)
  }

  public func typedArrayBufferForHandle(_ value: QJSValueHandle)
    -> QJSValueHandle?
  {
    QJSEngine.typedArrayBufferForHandle(value, in: self)
  }

  public func typedArrayBytesPtrForHandle(
    _ value: QJSValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    QJSEngine.typedArrayBytesPtrForHandle(value, in: self)
  }

  public func isArrayBufferHandle(_ value: QJSValueHandle) -> Bool {
    QJSEngine.isArrayBufferHandle(value, in: self)
  }

  public func typedArrayKindForHandle(_ value: QJSValueHandle) -> JSTypedArrayKind? {
    QJSEngine.typedArrayKindForHandle(value, in: self)
  }
}
