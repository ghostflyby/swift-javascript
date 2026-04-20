import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QuickJSEngine: _JSEngineTypedArrayDriver {
  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: QuickJSContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> QuickJSValueHandle? {
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
    return QuickJSValueHandle(ref: value, contextRef: context.ref)
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Int? {
    var size = 0
    guard JS_GetArrayBuffer(context.ref, &size, value.ref) != nil else {
      return nil
    }
    return size
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var size = 0
    let bytes = JS_GetArrayBuffer(context.ref, &size, value.ref)
    return (UnsafeMutableRawPointer(bytes), bytes == nil)
  }

  public static func makeTypedArrayHandle(
    in _: QuickJSContextHandle,
    kind _: JSTypedArrayKind,
    length _: Int
  ) -> QuickJSValueHandle? {
    nil
  }

  public static func makeTypedArrayHandle(
    in _: QuickJSContextHandle,
    kind _: JSTypedArrayKind,
    arrayBuffer _: QuickJSValueHandle
  ) -> QuickJSValueHandle? {
    nil
  }

  public static func makeTypedArrayHandle(
    in _: QuickJSContextHandle,
    kind _: JSTypedArrayKind,
    arrayBuffer _: QuickJSValueHandle,
    byteOffset _: Int,
    length _: Int
  ) -> QuickJSValueHandle? {
    nil
  }

  public static func typedArrayLengthForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
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
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
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
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
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
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
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
    return QuickJSValueHandle(ref: buffer, contextRef: context.ref)
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    guard let buffer = typedArrayBufferForHandle(value, in: context) else {
      return (nil, true)
    }
    return arrayBufferBytesPtrForHandle(buffer, in: context)
  }

  public static func isArrayBufferHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> Bool {
    JS_IsArrayBuffer(value.ref)
  }

  public static func typedArrayKindForHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
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
