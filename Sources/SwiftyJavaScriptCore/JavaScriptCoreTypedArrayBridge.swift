import JavaScriptCore
import SwiftJavaScript

extension JSTypedArrayKind {
  var javaScriptCoreTypedArrayType: JSTypedArrayType {
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

  init?(javaScriptCoreTypedArrayType: JSTypedArrayType) {
    switch javaScriptCoreTypedArrayType {
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
}

func makeJavaScriptCoreArrayBufferWithBytesNoCopy(
  in context: JSGlobalContextRef,
  bytes: UnsafeMutableRawPointer?,
  byteLength: Int,
  bytesDeallocator: JSTypedArrayBytesDeallocator?,
  deallocatorContext: UnsafeMutableRawPointer?
) -> JSObjectRef? {
  var exception: JSValueRef?
  let ref = JSObjectMakeArrayBufferWithBytesNoCopy(
    context,
    bytes,
    byteLength,
    bytesDeallocator,
    deallocatorContext,
    &exception
  )
  guard exception == nil else {
    return nil
  }
  return ref
}

func javaScriptCoreArrayBufferByteLength(
  of object: JSObjectRef,
  in context: JSContextRef
) -> Int? {
  var exception: JSValueRef?
  let length = JSObjectGetArrayBufferByteLength(context, object, &exception)
  guard exception == nil else {
    return nil
  }
  return length
}

func javaScriptCoreArrayBufferBytesPtr(
  of object: JSObjectRef,
  in context: JSContextRef
) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
  var exception: JSValueRef?
  let bytes = JSObjectGetArrayBufferBytesPtr(context, object, &exception)
  return (bytes, exception != nil)
}

func makeJavaScriptCoreTypedArray(
  in context: JSGlobalContextRef,
  type: JSTypedArrayType,
  length: Int
) -> JSObjectRef? {
  var exception: JSValueRef?
  let ref = JSObjectMakeTypedArray(context, type, length, &exception)
  guard exception == nil else {
    return nil
  }
  return ref
}

func makeJavaScriptCoreTypedArrayWithArrayBuffer(
  in context: JSGlobalContextRef,
  type: JSTypedArrayType,
  arrayBuffer: JSObjectRef
) -> JSObjectRef? {
  var exception: JSValueRef?
  let ref = JSObjectMakeTypedArrayWithArrayBuffer(context, type, arrayBuffer, &exception)
  guard exception == nil else {
    return nil
  }
  return ref
}

func makeJavaScriptCoreTypedArrayWithArrayBufferAndOffset(
  in context: JSGlobalContextRef,
  type: JSTypedArrayType,
  arrayBuffer: JSObjectRef,
  byteOffset: Int,
  length: Int
) -> JSObjectRef? {
  var exception: JSValueRef?
  let ref = JSObjectMakeTypedArrayWithArrayBufferAndOffset(
    context,
    type,
    arrayBuffer,
    byteOffset,
    length,
    &exception
  )
  guard exception == nil else {
    return nil
  }
  return ref
}

func javaScriptCoreTypedArrayLength(
  of object: JSObjectRef,
  in context: JSContextRef
) -> Int? {
  var exception: JSValueRef?
  let length = JSObjectGetTypedArrayLength(context, object, &exception)
  guard exception == nil else {
    return nil
  }
  return length
}

func javaScriptCoreTypedArrayByteLength(
  of object: JSObjectRef,
  in context: JSContextRef
) -> Int? {
  var exception: JSValueRef?
  let length = JSObjectGetTypedArrayByteLength(context, object, &exception)
  guard exception == nil else {
    return nil
  }
  return length
}

func javaScriptCoreTypedArrayByteOffset(
  of object: JSObjectRef,
  in context: JSContextRef
) -> Int? {
  var exception: JSValueRef?
  let offset = JSObjectGetTypedArrayByteOffset(context, object, &exception)
  guard exception == nil else {
    return nil
  }
  return offset
}

func javaScriptCoreTypedArrayBuffer(
  of object: JSObjectRef,
  in context: JSContextRef
) -> JSObjectRef? {
  var exception: JSValueRef?
  let buffer = JSObjectGetTypedArrayBuffer(context, object, &exception)
  guard exception == nil else {
    return nil
  }
  return buffer
}

func javaScriptCoreTypedArrayBytesPtr(
  of object: JSObjectRef,
  in context: JSContextRef
) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
  var exception: JSValueRef?
  let bytes = JSObjectGetTypedArrayBytesPtr(context, object, &exception)
  return (bytes, exception != nil)
}

func javaScriptCoreTypedArrayType(
  of value: JSValueRef,
  in context: JSContextRef
) -> JSTypedArrayType? {
  var exception: JSValueRef?
  let type = JSValueGetTypedArrayType(context, value, &exception)
  guard exception == nil else {
    return nil
  }
  return type
}
