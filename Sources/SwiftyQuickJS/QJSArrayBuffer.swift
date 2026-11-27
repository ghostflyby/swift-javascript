import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

// MARK: - QuickJS buffers (S10)
//
// Mirrors the JavaScriptCore wrappers: real structs over the `QJSEngine`
// typed-array statics over raw values, with core holding the byte
// allocation/copy helpers and the wrapper implementing the byte/shape access.
// Failure semantics are unchanged: the driver clears the pending exception and
// releases the deallocator box it may have built, and the shared core helper
// releases the bytes it allocated exactly once because the engine never took
// them.

/// The QuickJS ArrayBuffer wrapper.
public struct QJSArrayBuffer: SwiftJavaScript.JSArrayBuffer, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext

  package let value: QJSValue

  package init(value: consuming QJSValue) {
    self.value = value
  }

  public borrowing func withValue<R: ~Copyable>(_ body: (borrowing QJSValue) -> R) -> R {
    body(value)
  }

  // MARK: - Construction

  public init(byteLength: Int, in context: borrowing QJSInstantContext) {
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

  public init(copying bytes: [UInt8], in context: borrowing QJSInstantContext) {
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
    in context: borrowing QJSInstantContext
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
    value: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) {
    guard value.isArrayBuffer(in: context) else {
      return nil
    }
    self.init(value: context.anchorBorrowed(value.value))
  }

  // MARK: - Bytes

  public var byteLength: Int {
    guard
      let length = quickJSArrayBufferByteLength(
        value.value,
        in: value.contextRef
      )
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
    let access = quickJSArrayBufferBytesPtr(value.value, in: value.contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access ArrayBuffer bytes")
    }
    return body(UnsafeRawBufferPointer(start: access.bytes, count: byteLength))
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = quickJSArrayBufferBytesPtr(value.value, in: value.contextRef)
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable ArrayBuffer bytes")
    }
    return body(UnsafeMutableRawBufferPointer(start: access.bytes, count: byteLength))
  }
}

/// The QuickJS TypedArray wrapper.
public struct QJSTypedArray: SwiftJavaScript.JSTypedArray, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext
  public typealias Buffer = QJSArrayBuffer

  package let value: QJSValue

  package init(value: consuming QJSValue) {
    self.value = value
  }

  public borrowing func withValue<R: ~Copyable>(_ body: (borrowing QJSValue) -> R) -> R {
    body(value)
  }

  // MARK: - Construction

  public init(kind: JSTypedArrayKind, length: Int, in context: borrowing QJSInstantContext) {
    precondition(length >= 0, "TypedArray length must be non-negative")

    guard
      let created = quickJSMakeTypedArray(
        in: context.contextRef,
        kind: kind,
        length: length
      )
    else {
      preconditionFailure("Failed to create TypedArray")
    }
    self.init(value: context.adoptCreated(created))
  }

  public init(
    kind: JSTypedArrayKind,
    buffer: borrowing QJSArrayBuffer,
    byteOffset: Int,
    length: Int?,
    in context: borrowing QJSInstantContext
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    let bufferValue = buffer.value.value
    let created: CQuickJSValue?
    if let length {
      created = quickJSMakeTypedArray(
        in: context.contextRef,
        kind: kind,
        arrayBuffer: bufferValue,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      created = quickJSMakeTypedArray(
        in: context.contextRef,
        kind: kind,
        arrayBuffer: bufferValue
      )
    } else {
      created = quickJSMakeTypedArray(
        in: context.contextRef,
        kind: kind,
        arrayBuffer: bufferValue,
        byteOffset: byteOffset,
        length: buffer.remainingElementCount(from: byteOffset, kind: kind)
      )
    }

    guard let created else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }
    self.init(value: context.adoptCreated(created))
  }

  public init?(
    value: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) {
    guard value.isTypedArray(in: context) else {
      return nil
    }
    self.init(value: context.anchorBorrowed(value.value))
  }

  // MARK: - Shape

  public var kind: JSTypedArrayKind {
    guard
      let kind = quickJSTypedArrayKind(value.value, in: value.contextRef)
    else {
      preconditionFailure("Wrapped value is not a TypedArray")
    }
    return kind
  }

  public var length: Int {
    guard
      let length = quickJSTypedArrayLength(value.value, in: value.contextRef)
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard
      let byteLength = quickJSTypedArrayByteLength(
        value.value,
        in: value.contextRef
      )
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return byteLength
  }

  public var byteOffset: Int {
    guard
      let byteOffset = quickJSTypedArrayByteOffset(
        value.value,
        in: value.contextRef
      )
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return byteOffset
  }

  /// QuickJS returns a new reference to the backing buffer, so the wrapper
  /// adopts it into the context default scope exactly once.
  public var buffer: QJSArrayBuffer {
    let contextRef = value.contextRef
    guard
      let bufferValue = quickJSTypedArrayBuffer(value.value, in: contextRef)
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    guard let target = QJSScopeStacks.defaultFrame(for: contextRef) else {
      preconditionFailure("TypedArray buffer requires an open context default scope")
    }
    target.track(bufferValue)
    return QJSArrayBuffer(
      value: QJSValue(value: bufferValue, contextRef: contextRef))
  }

  // MARK: - Bytes

  public var bytes: [UInt8] {
    withUnsafeBytes { Array($0) }
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(
    _ body: (UnsafeRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = quickJSTypedArrayBytesPtr(value.value, in: value.contextRef)
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
    let access = quickJSTypedArrayBytesPtr(value.value, in: value.contextRef)
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

/// Heap box carrying an ArrayBuffer's byte deallocator across the C handoff.
final class QuickJSArrayBufferDeallocatorBox: @unchecked Sendable {
  let deallocator: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
  let context: UnsafeMutableRawPointer?

  init(
    deallocator:
      @escaping @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void,
    context: UnsafeMutableRawPointer?
  ) {
    self.deallocator = deallocator
    self.context = context
  }
}

extension QJSInstantContext: JSArrayBufferHostScope {
  package func adoptArrayBufferBytesNoCopy(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator:
      @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
      ) -> Void,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> QJSValue? {
    guard
      let created = quickJSMakeArrayBufferWithBytesNoCopy(
        in: contextRef,
        bytes: bytes,
        byteLength: byteLength,
        bytesDeallocator: bytesDeallocator,
        deallocatorContext: deallocatorContext
      )
    else {
      return nil
    }
    return adoptCreated(created)
  }
}
