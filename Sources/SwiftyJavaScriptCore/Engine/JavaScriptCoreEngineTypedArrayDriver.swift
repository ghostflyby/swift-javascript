import JavaScriptCore
import SwiftJavaScript

extension JSCEngine: JSEngineTypedArrayDriver {
  package static func makeArrayBufferWithBytesNoCopyHandle(
    in context: JSCContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<JSCEngine>? {
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

    return JSCValueHandle(ref: objectRef)
  }

  package static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreArrayBufferByteLength(of: objectRef, in: context.ref)
    }
  }

  package static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return javaScriptCoreArrayBufferBytesPtr(of: objectRef, in: context.ref)
    }
  }

  package static func makeTypedArrayHandle(
    in context: JSCContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<JSCEngine>? {
    guard
      let objectRef = makeJavaScriptCoreTypedArray(
        in: context.ref,
        type: kind.javaScriptCoreTypedArrayType,
        length: length
      )
    else {
      return nil
    }

    return JSCValueHandle(ref: objectRef)
  }

  package static func makeTypedArrayHandle(
    in context: JSCContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JSCEngine>
  ) -> JSValueHandle<JSCEngine>? {
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

      return JSCValueHandle(ref: typedArrayRef)
    }
  }

  package static func makeTypedArrayHandle(
    in context: JSCContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JSCEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<JSCEngine>? {
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

      return JSCValueHandle(ref: typedArrayRef)
    }
  }

  package static func typedArrayLengthForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayLength(of: objectRef, in: context.ref)
    }
  }

  package static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayByteLength(of: objectRef, in: context.ref)
    }
  }

  package static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayByteOffset(of: objectRef, in: context.ref)
    }
  }

  package static func typedArrayBufferForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSValueHandle<JSCEngine>? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard let bufferRef = javaScriptCoreTypedArrayBuffer(of: objectRef, in: context.ref) else {
        return nil
      }

      return JSCValueHandle(ref: bufferRef)
    }
  }

  package static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return javaScriptCoreTypedArrayBytesPtr(of: objectRef, in: context.ref)
    }
  }

  package static func isArrayBufferHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool {
    guard
      let type = javaScriptCoreTypedArrayType(of: value.ref, in: context.ref)
    else {
      return false
    }

    return type == kJSTypedArrayTypeArrayBuffer
  }

  package static func typedArrayKindForHandle(
    _ value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
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

extension JSCContextHandle: JSContextTypedArrayDriver {
  package func makeArrayBufferWithBytesNoCopyHandle(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSCValueHandle? {
    JSCEngine.makeArrayBufferWithBytesNoCopyHandle(
      in: self,
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: bytesDeallocator,
      deallocatorContext: deallocatorContext
    )
  }

  package func arrayBufferByteLengthForHandle(_ value: JSCValueHandle) -> Int? {
    JSCEngine.arrayBufferByteLengthForHandle(value, in: self)
  }

  package func arrayBufferBytesPtrForHandle(
    _ value: JSCValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    JSCEngine.arrayBufferBytesPtrForHandle(value, in: self)
  }

  package func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSCValueHandle? {
    JSCEngine.makeTypedArrayHandle(in: self, kind: kind, length: length)
  }

  package func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: JSCValueHandle
  ) -> JSCValueHandle? {
    JSCEngine.makeTypedArrayHandle(in: self, kind: kind, arrayBuffer: arrayBuffer)
  }

  package func makeTypedArrayHandle(
    kind: JSTypedArrayKind,
    arrayBuffer: JSCValueHandle,
    byteOffset: Int,
    length: Int
  ) -> JSCValueHandle? {
    JSCEngine.makeTypedArrayHandle(
      in: self,
      kind: kind,
      arrayBuffer: arrayBuffer,
      byteOffset: byteOffset,
      length: length
    )
  }

  package func typedArrayLengthForHandle(_ value: JSCValueHandle) -> Int? {
    JSCEngine.typedArrayLengthForHandle(value, in: self)
  }

  package func typedArrayByteLengthForHandle(_ value: JSCValueHandle) -> Int? {
    JSCEngine.typedArrayByteLengthForHandle(value, in: self)
  }

  package func typedArrayByteOffsetForHandle(_ value: JSCValueHandle) -> Int? {
    JSCEngine.typedArrayByteOffsetForHandle(value, in: self)
  }

  package func typedArrayBufferForHandle(_ value: JSCValueHandle)
    -> JSCValueHandle?
  {
    JSCEngine.typedArrayBufferForHandle(value, in: self)
  }

  package func typedArrayBytesPtrForHandle(
    _ value: JSCValueHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    JSCEngine.typedArrayBytesPtrForHandle(value, in: self)
  }

  package func isArrayBufferHandle(_ value: JSCValueHandle) -> Bool {
    JSCEngine.isArrayBufferHandle(value, in: self)
  }

  package func typedArrayKindForHandle(
    _ value: JSCValueHandle
  ) -> JSTypedArrayKind? {
    JSCEngine.typedArrayKindForHandle(value, in: self)
  }
}
