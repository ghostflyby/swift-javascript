import JavaScriptCore
import SwiftJavaScript

// MARK: - JavaScriptCore buffers (S10)
//
// Both wrappers are real structs over the `JavaScriptCore` typed-array statics over
// raw refs: the engine owns every C call, core owns the byte allocation/copy
// helpers, and the wrapper states the JavaScriptCore identity, the byte/shape
// access, and the arena adoption.

/// The JavaScriptCore ArrayBuffer wrapper.
public struct JSCArrayBuffer: SwiftJavaScript.JSArrayBuffer, ~Copyable, ~Escapable {
  public typealias Context = JSCContext
  public typealias Value = JSCValue
  public typealias InstantContext = JSCInstantContext

  package let value: JSCValue

  package init(value: consuming JSCValue) {
    self.value = value
  }

  public borrowing func withValue<R: ~Copyable>(_ body: (borrowing JSCValue) -> R) -> R {
    body(value)
  }

  // MARK: - Construction

  public init(byteLength: Int, in context: borrowing JSCInstantContext) {
    precondition(byteLength >= 0, "ArrayBuffer byteLength must be non-negative")

    guard
      let value = adoptArrayBufferBytesNoCopy(
        allocateZeroedArrayBufferBytes(byteLength: byteLength),
        byteLength: byteLength,
        in: context
      )
    else {
      preconditionFailure("Failed to create ArrayBuffer")
    }
    self.init(value: value)
  }

  public init(copying bytes: [UInt8], in context: borrowing JSCInstantContext) {
    guard
      let value = adoptArrayBufferBytesNoCopy(
        allocateArrayBufferBytes(copying: bytes),
        byteLength: bytes.count,
        in: context
      )
    else {
      preconditionFailure("Failed to create ArrayBuffer from bytes")
    }
    self.init(value: value)
  }

  public init(
    copying bytes: UnsafeRawBufferPointer,
    in context: borrowing JSCInstantContext
  ) {
    guard
      let value = adoptArrayBufferBytesNoCopy(
        allocateArrayBufferBytes(copying: bytes),
        byteLength: bytes.count,
        in: context
      )
    else {
      preconditionFailure("Failed to create ArrayBuffer from bytes")
    }
    self.init(value: value)
  }

  public init?(
    value: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) {
    guard value.isArrayBuffer(in: context) else {
      return nil
    }
    self.init(value: context.anchorBorrowedHandle(value.ref))
  }

  // MARK: - Bytes

  public var byteLength: Int {
    guard
      let length = javaScriptCoreArrayBufferByteLengthForHandle(
        value.ref, in: value.contextRef)
    else {
      preconditionFailure("Failed to read ArrayBuffer byteLength")
    }
    return length
  }

  public var bytes: [UInt8] {
    withUnsafeBytes { Array($0) }
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(
    _ body: (UnsafeRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = javaScriptCoreArrayBufferBytesPtrForHandle(value.ref, in: value.contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access ArrayBuffer bytes")
    }
    return body(UnsafeRawBufferPointer(start: access.bytes, count: byteLength))
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = javaScriptCoreArrayBufferBytesPtrForHandle(value.ref, in: value.contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable ArrayBuffer bytes")
    }
    return body(UnsafeMutableRawBufferPointer(start: access.bytes, count: byteLength))
  }
}

/// The JavaScriptCore TypedArray wrapper.
public struct JSCTypedArray: SwiftJavaScript.JSTypedArray, ~Copyable, ~Escapable {
  public typealias Context = JSCContext
  public typealias Value = JSCValue
  public typealias InstantContext = JSCInstantContext
  public typealias Buffer = JSCArrayBuffer

  package let value: JSCValue

  package init(value: consuming JSCValue) {
    self.value = value
  }

  public borrowing func withValue<R: ~Copyable>(_ body: (borrowing JSCValue) -> R) -> R {
    body(value)
  }

  // MARK: - Construction

  public init(kind: JSTypedArrayKind, length: Int, in context: borrowing JSCInstantContext) {
    precondition(length >= 0, "TypedArray length must be non-negative")

    guard
      let ref = javaScriptCoreMakeTypedArrayHandle(
        in: context.contextRef,
        kind: kind,
        length: length
      )
    else {
      preconditionFailure("Failed to create TypedArray")
    }
    self.init(value: context.adoptCreatedHandle(ref))
  }

  public init(
    kind: JSTypedArrayKind,
    buffer: borrowing JSCArrayBuffer,
    byteOffset: Int,
    length: Int?,
    in context: borrowing JSCInstantContext
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    let bufferRef = buffer.value.ref
    let ref: JSValueRef?
    if let length {
      ref = javaScriptCoreMakeTypedArrayHandle(
        in: context.contextRef,
        kind: kind,
        arrayBuffer: bufferRef,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      ref = javaScriptCoreMakeTypedArrayHandle(
        in: context.contextRef,
        kind: kind,
        arrayBuffer: bufferRef
      )
    } else {
      ref = javaScriptCoreMakeTypedArrayHandle(
        in: context.contextRef,
        kind: kind,
        arrayBuffer: bufferRef,
        byteOffset: byteOffset,
        length: buffer.remainingElementCount(from: byteOffset, kind: kind)
      )
    }

    guard let ref else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }
    self.init(value: context.adoptCreatedHandle(ref))
  }

  public init?(
    value: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) {
    guard value.isTypedArray(in: context) else {
      return nil
    }
    self.init(value: context.anchorBorrowedHandle(value.ref))
  }

  // MARK: - Shape

  public var kind: JSTypedArrayKind {
    guard
      let kind = javaScriptCoreTypedArrayKindForHandle(value.ref, in: value.contextRef)
    else {
      preconditionFailure("Wrapped value is not a TypedArray")
    }
    return kind
  }

  public var length: Int {
    guard
      let length = javaScriptCoreTypedArrayLengthForHandle(value.ref, in: value.contextRef)
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard
      let byteLength = javaScriptCoreTypedArrayByteLengthForHandle(
        value.ref, in: value.contextRef)
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return byteLength
  }

  public var byteOffset: Int {
    guard
      let byteOffset = javaScriptCoreTypedArrayByteOffsetForHandle(
        value.ref, in: value.contextRef)
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return byteOffset
  }

  /// JavaScriptCore returns the buffer as an unprotected object reference, so
  /// the wrapper adopts it into the context default scope exactly once.
  @_lifetime(borrow self)
  public func buffer() -> JSCArrayBuffer {
    let contextRef = value.contextRef
    guard
      let bufferRef = javaScriptCoreTypedArrayBufferForHandle(value.ref, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    guard let target = JSCScopeStacks.defaultFrame(for: contextRef) else {
      preconditionFailure("TypedArray buffer requires an open context default scope")
    }
    target.track(bufferRef)
    return JSCArrayBuffer(
      value: JSCValue(ref: bufferRef, contextRef: contextRef))
  }

  // MARK: - Bytes

  public var bytes: [UInt8] {
    withUnsafeBytes { Array($0) }
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(
    _ body: (UnsafeRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = javaScriptCoreTypedArrayBytesPtrForHandle(value.ref, in: value.contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access TypedArray bytes")
    }
    // The driver reports the backing buffer's base pointer; the array's own
    // view starts `byteOffset` bytes into it.
    let start = access.bytes?.advanced(by: byteOffset)
    return body(UnsafeRawBufferPointer(start: start, count: byteLength))
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = javaScriptCoreTypedArrayBytesPtrForHandle(value.ref, in: value.contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    return body(UnsafeMutableRawBufferPointer(start: start, count: byteLength))
  }
}

// MARK: - No-copy byte handover
//
// The instant context owns the only two pieces the core helper cannot reach:
// the driver call and the arena adoption.

extension JSCInstantContext: JSArrayBufferHostScope {
  package func adoptArrayBufferBytesNoCopy(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator:
      @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
      ) -> Void,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSCValue? {
    guard
      let ref = javaScriptCoreMakeArrayBufferWithBytesNoCopyHandle(
        in: contextRef,
        bytes: bytes,
        byteLength: byteLength,
        bytesDeallocator: bytesDeallocator,
        deallocatorContext: deallocatorContext
      )
    else {
      return nil
    }
    return adoptCreatedHandle(ref)
  }
}
