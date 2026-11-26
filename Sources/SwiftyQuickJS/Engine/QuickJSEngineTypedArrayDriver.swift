import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QJSEngine {
  package static func makeArrayBufferWithBytesNoCopy(
    in context: OpaquePointer,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> CQuickJSValue? {
    quickJSUpdateStackTop(context)
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
      context,
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
    return value
  }

  package static func arrayBufferByteLength(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Int? {
    quickJSUpdateStackTop(context)
    var size = 0
    guard JS_GetArrayBuffer(context, &size, value) != nil else {
      return nil
    }
    return size
  }

  package static func arrayBufferBytesPtr(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    quickJSUpdateStackTop(context)
    var size = 0
    let bytes = JS_GetArrayBuffer(context, &size, value)
    return (UnsafeMutableRawPointer(bytes), bytes == nil)
  }

  package static func makeTypedArray(
    in context: OpaquePointer,
    kind: JSTypedArrayKind,
    length: Int
  ) -> CQuickJSValue? {
    quickJSUpdateStackTop(context)
    var arguments = [JS_NewFloat64(context, Double(length))]
    return quickJSMakeTypedArray(in: context, kind: kind, arguments: &arguments)
  }

  package static func makeTypedArray(
    in context: OpaquePointer,
    kind: JSTypedArrayKind,
    arrayBuffer: CQuickJSValue
  ) -> CQuickJSValue? {
    quickJSUpdateStackTop(context)
    var arguments = [
      arrayBuffer,
      JS_NewFloat64(context, 0),
      quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED)),
    ]
    return quickJSMakeTypedArray(in: context, kind: kind, arguments: &arguments)
  }

  package static func makeTypedArray(
    in context: OpaquePointer,
    kind: JSTypedArrayKind,
    arrayBuffer: CQuickJSValue,
    byteOffset: Int,
    length: Int
  ) -> CQuickJSValue? {
    quickJSUpdateStackTop(context)
    var arguments = [
      arrayBuffer,
      JS_NewFloat64(context, Double(byteOffset)),
      JS_NewFloat64(context, Double(length)),
    ]
    return quickJSMakeTypedArray(in: context, kind: kind, arguments: &arguments)
  }

  package static func typedArrayLength(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Int? {
    quickJSUpdateStackTop(context)
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context,
      value,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context, buffer)
    guard bytesPerElement > 0 else {
      return nil
    }
    return byteLength / bytesPerElement
  }

  package static func typedArrayByteLength(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Int? {
    quickJSUpdateStackTop(context)
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context,
      value,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context, buffer)
    return byteLength
  }

  package static func typedArrayByteOffset(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Int? {
    quickJSUpdateStackTop(context)
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context,
      value,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context, buffer)
    return byteOffset
  }

  /// A new owning reference to the backing buffer.
  package static func typedArrayBuffer(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    quickJSUpdateStackTop(context)
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context,
      value,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    return buffer
  }

  package static func typedArrayBytesPtr(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    quickJSUpdateStackTop(context)
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context,
      value,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return (nil, true)
    }
    defer { JS_FreeValue(context, buffer) }
    return arrayBufferBytesPtr(buffer, in: context)
  }

  package static func isArrayBuffer(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool {
    _ = context
    return JS_IsArrayBuffer(value)
  }

  package static func typedArrayKind(
    _ value: CQuickJSValue,
    in context: OpaquePointer
  ) -> JSTypedArrayKind? {
    _ = context
    switch JS_GetTypedArrayType(value) {
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

private func quickJSMakeTypedArray(
  in context: OpaquePointer,
  kind: JSTypedArrayKind,
  arguments: inout [CQuickJSValue]
) -> CQuickJSValue? {
  let value = arguments.withUnsafeMutableBufferPointer { buffer in
    JS_NewTypedArray(
      context,
      Int32(buffer.count),
      buffer.baseAddress,
      quickJSTypedArrayType(for: kind)
    )
  }
  guard !JS_IsException(value) else {
    quickJSClearPendingException(in: context)
    return nil
  }
  return value
}

private func quickJSClearPendingException(in context: OpaquePointer) {
  let exception = JS_GetException(context)
  JS_FreeValue(context, exception)
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
