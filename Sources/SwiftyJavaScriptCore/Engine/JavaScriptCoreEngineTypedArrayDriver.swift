import JavaScriptCore
import SwiftJavaScript

extension JavaScriptCoreEngine: JSEngineTypedArrayDriver {
  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: JavaScriptCoreContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard
      let objectRef = makeJavaScriptCoreArrayBufferWithBytesNoCopy(
        in: context.ref,
        bytes: bytes,
        byteLength: byteLength,
        bytesDeallocator: bytesDeallocator,
        deallocatorContext: deallocatorContext
      )
    else {
      return nil
    }

    return JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref)
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreArrayBufferByteLength(of: objectRef, in: context.ref)
    }
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return javaScriptCoreArrayBufferBytesPtr(of: objectRef, in: context.ref)
    }
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard
      let objectRef = makeJavaScriptCoreTypedArray(
        in: context.ref,
        type: kind.javaScriptCoreTypedArrayType,
        length: length
      )
    else {
      return nil
    }

    return JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref)
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JavaScriptCoreEngine>
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch javaScriptCoreObjectRef(for: arrayBuffer, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeJavaScriptCoreTypedArrayWithArrayBuffer(
          in: context.ref,
          type: kind.javaScriptCoreTypedArrayType,
          arrayBuffer: objectRef
        )
      else {
        return nil
      }

      return JavaScriptCoreValueHandle(ref: typedArrayRef, contextRef: context.ref)
    }
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JavaScriptCoreEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch javaScriptCoreObjectRef(for: arrayBuffer, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeJavaScriptCoreTypedArrayWithArrayBufferAndOffset(
          in: context.ref,
          type: kind.javaScriptCoreTypedArrayType,
          arrayBuffer: objectRef,
          byteOffset: byteOffset,
          length: length
        )
      else {
        return nil
      }

      return JavaScriptCoreValueHandle(ref: typedArrayRef, contextRef: context.ref)
    }
  }

  public static func typedArrayLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayLength(of: objectRef, in: context.ref)
    }
  }

  public static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayByteLength(of: objectRef, in: context.ref)
    }
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayByteOffset(of: objectRef, in: context.ref)
    }
  }

  public static func typedArrayBufferForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard let bufferRef = javaScriptCoreTypedArrayBuffer(of: objectRef, in: context.ref) else {
        return nil
      }

      return JavaScriptCoreValueHandle(ref: bufferRef, contextRef: context.ref)
    }
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return javaScriptCoreTypedArrayBytesPtr(of: objectRef, in: context.ref)
    }
  }

  public static func isArrayBufferHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    guard
      let type = javaScriptCoreTypedArrayType(of: value.ref, in: context.ref)
    else {
      return false
    }

    return type == kJSTypedArrayTypeArrayBuffer
  }

  public static func typedArrayKindForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSTypedArrayKind? {
    guard
      let type = javaScriptCoreTypedArrayType(of: value.ref, in: context.ref)
    else {
      return nil
    }

    return JSTypedArrayKind(javaScriptCoreTypedArrayType: type)
  }
}
