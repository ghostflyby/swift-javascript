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

    return JavaScriptCoreValueHandle(ref: objectRef)
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

    return JavaScriptCoreValueHandle(ref: objectRef)
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

      return JavaScriptCoreValueHandle(ref: typedArrayRef)
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

      return JavaScriptCoreValueHandle(ref: typedArrayRef)
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

      return JavaScriptCoreValueHandle(ref: bufferRef)
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

// MARK: - Context-side driver conformance (Stage 2B)

extension JavaScriptCoreContextHandle: JSContextTypedArrayDriver {
  public func makeArrayBufferWithBytesNoCopyHandle(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JavaScriptCoreValueHandle? {
    JavaScriptCoreEngine.makeArrayBufferWithBytesNoCopyHandle(
      in: self,
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: bytesDeallocator,
      deallocatorContext: deallocatorContext
    )
  }

  public func arrayBufferByteLengthForHandle(_ value: JavaScriptCoreValueHandle) -> Int? {
    JavaScriptCoreEngine.arrayBufferByteLengthForHandle(value, in: self)
  }

  public func arrayBufferBytesPtrForHandle(
    _ value: JavaScriptCoreValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    JavaScriptCoreEngine.arrayBufferBytesPtrForHandle(value, in: self)
  }

  public func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    length: Int
  ) -> JavaScriptCoreValueHandle? {
    JavaScriptCoreEngine.makeTypedArrayHandle(in: self, kind: kind, length: length)
  }

  public func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: JavaScriptCoreValueHandle
  ) -> JavaScriptCoreValueHandle? {
    JavaScriptCoreEngine.makeTypedArrayHandle(in: self, kind: kind, arrayBuffer: arrayBuffer)
  }

  public func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: JavaScriptCoreValueHandle,
    byteOffset: Int,
    length: Int
  ) -> JavaScriptCoreValueHandle? {
    JavaScriptCoreEngine.makeTypedArrayHandle(
      in: self,
      kind: kind,
      arrayBuffer: arrayBuffer,
      byteOffset: byteOffset,
      length: length
    )
  }

  public func typedArrayLengthForHandle(_ value: JavaScriptCoreValueHandle) -> Int? {
    JavaScriptCoreEngine.typedArrayLengthForHandle(value, in: self)
  }

  public func typedArrayByteLengthForHandle(_ value: JavaScriptCoreValueHandle) -> Int? {
    JavaScriptCoreEngine.typedArrayByteLengthForHandle(value, in: self)
  }

  public func typedArrayByteOffsetForHandle(_ value: JavaScriptCoreValueHandle) -> Int? {
    JavaScriptCoreEngine.typedArrayByteOffsetForHandle(value, in: self)
  }

  public func typedArrayBufferForHandle(_ value: JavaScriptCoreValueHandle)
    -> JavaScriptCoreValueHandle?
  {
    JavaScriptCoreEngine.typedArrayBufferForHandle(value, in: self)
  }

  public func typedArrayBytesPtrForHandle(
    _ value: JavaScriptCoreValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    JavaScriptCoreEngine.typedArrayBytesPtrForHandle(value, in: self)
  }

  public func isArrayBufferHandle(_ value: JavaScriptCoreValueHandle) -> Bool {
    JavaScriptCoreEngine.isArrayBufferHandle(value, in: self)
  }

  public func typedArrayKindForHandle(
    _ value: JavaScriptCoreValueHandle
  ) -> JSTypedArrayKind? {
    JavaScriptCoreEngine.typedArrayKindForHandle(value, in: self)
  }
}
