import JavaScriptCore
import SwiftJavaScript

extension JSCEngine {
  package static func makeArrayBufferWithBytesNoCopyHandle(
    in context: JSGlobalContextRef,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueRef? {
    guard
      let objectRef = makeJavaScriptCoreArrayBufferWithBytesNoCopy(
        in: context,
        bytes: bytes,
        byteLength: byteLength,
        bytesDeallocator: bytesDeallocator,
        deallocatorContext: deallocatorContext
      )
    else {
      return nil
    }

    return objectRef
  }

  package static func arrayBufferByteLengthForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreArrayBufferByteLength(of: objectRef, in: context)
    }
  }

  package static func arrayBufferBytesPtrForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return javaScriptCoreArrayBufferBytesPtr(of: objectRef, in: context)
    }
  }

  package static func makeTypedArrayHandle(
    in context: JSGlobalContextRef,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueRef? {
    guard
      let objectRef = makeJavaScriptCoreTypedArray(
        in: context,
        type: kind.javaScriptCoreTypedArrayType,
        length: length
      )
    else {
      return nil
    }

    return objectRef
  }

  package static func makeTypedArrayHandle(
    in context: JSGlobalContextRef,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueRef
  ) -> JSValueRef? {
    switch javaScriptCoreObjectRef(for: arrayBuffer, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeJavaScriptCoreTypedArrayWithArrayBuffer(
          in: context,
          type: kind.javaScriptCoreTypedArrayType,
          arrayBuffer: objectRef
        )
      else {
        return nil
      }

      return typedArrayRef
    }
  }

  package static func makeTypedArrayHandle(
    in context: JSGlobalContextRef,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueRef,
    byteOffset: Int,
    length: Int
  ) -> JSValueRef? {
    switch javaScriptCoreObjectRef(for: arrayBuffer, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeJavaScriptCoreTypedArrayWithArrayBufferAndOffset(
          in: context,
          type: kind.javaScriptCoreTypedArrayType,
          arrayBuffer: objectRef,
          byteOffset: byteOffset,
          length: length
        )
      else {
        return nil
      }

      return typedArrayRef
    }
  }

  package static func typedArrayLengthForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayLength(of: objectRef, in: context)
    }
  }

  package static func typedArrayByteLengthForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayByteLength(of: objectRef, in: context)
    }
  }

  package static func typedArrayByteOffsetForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Int? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return javaScriptCoreTypedArrayByteOffset(of: objectRef, in: context)
    }
  }

  package static func typedArrayBufferForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSValueRef? {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard let bufferRef = javaScriptCoreTypedArrayBuffer(of: objectRef, in: context) else {
        return nil
      }

      return bufferRef
    }
  }

  package static func typedArrayBytesPtrForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch javaScriptCoreObjectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return javaScriptCoreTypedArrayBytesPtr(of: objectRef, in: context)
    }
  }

  package static func isArrayBufferHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    guard
      let type = javaScriptCoreTypedArrayType(of: value, in: context)
    else {
      return false
    }

    return type == kJSTypedArrayTypeArrayBuffer
  }

  package static func typedArrayKindForHandle(
    _ value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSTypedArrayKind? {
    guard
      let type = javaScriptCoreTypedArrayType(of: value, in: context)
    else {
      return nil
    }

    return JSTypedArrayKind(javaScriptCoreTypedArrayType: type)
  }
}

// MARK: - Context-side driver conformance (Stage 2B)
