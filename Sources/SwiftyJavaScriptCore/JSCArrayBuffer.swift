import JavaScriptCore
import SwiftJavaScript

// MARK: - JavaScriptCore buffers (S10)
//
// Both wrappers are real structs over the `JSCContextHandle` typed-array
// driver: the driver owns every C call, core owns the byte allocation/copy
// helpers and the `byteOffset` overlay, and the wrapper only states the
// JavaScriptCore identity and arena adoption.

/// The JavaScriptCore ArrayBuffer wrapper.
public struct JSCArrayBuffer: SwiftJavaScript.JSArrayBuffer, ~Copyable {
  public typealias Context = JSCContext
  public typealias ContextHandle = JSCContextHandle
  public typealias Value = JSCValue
  public typealias InstantContext = JSCInstantContext

  package let value: JSCValue

  package init(value: consuming JSCValue) {
    self.value = value
  }

  public var contextHandle: JSCContextHandle { value.contextHandle }

  public borrowing func borrowHandle() -> JSCValueHandle {
    value.borrowHandle()
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
    self.init(value: context.anchorBorrowedHandle(value.borrowHandle()))
  }
}

/// The JavaScriptCore TypedArray wrapper.
public struct JSCTypedArray: SwiftJavaScript.JSTypedArray, ~Copyable {
  public typealias Context = JSCContext
  public typealias ContextHandle = JSCContextHandle
  public typealias Value = JSCValue
  public typealias InstantContext = JSCInstantContext
  public typealias Buffer = JSCArrayBuffer

  package let value: JSCValue

  package init(value: consuming JSCValue) {
    self.value = value
  }

  public var contextHandle: JSCContextHandle { value.contextHandle }

  public borrowing func borrowHandle() -> JSCValueHandle {
    value.borrowHandle()
  }

  public borrowing func withValue<R: ~Copyable>(_ body: (borrowing JSCValue) -> R) -> R {
    body(value)
  }

  // MARK: - Construction

  public init(kind: JSTypedArrayKind, length: Int, in context: borrowing JSCInstantContext) {
    precondition(length >= 0, "TypedArray length must be non-negative")

    guard
      let handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        length: length
      )
    else {
      preconditionFailure("Failed to create TypedArray")
    }
    self.init(
      value: context.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
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

    let bufferHandle = buffer.borrowHandle()
    let handle: JSCValueHandle?
    if let length {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        arrayBuffer: bufferHandle
      )
    } else {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: buffer.remainingElementCount(from: byteOffset, kind: kind)
      )
    }

    guard let handle else {
      preconditionFailure("Failed to create TypedArray from ArrayBuffer")
    }
    self.init(
      value: context.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
  }

  public init?(
    value: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) {
    guard value.isTypedArray(in: context) else {
      return nil
    }
    self.init(value: context.anchorBorrowedHandle(value.borrowHandle()))
  }

  // MARK: - Shape

  /// JavaScriptCore returns the buffer as an unprotected object reference, so
  /// the wrapper adopts it into the context default scope exactly once.
  public var buffer: JSCArrayBuffer {
    guard
      let bufferHandle = contextHandle.typedArrayBufferForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    guard
      let target = ScopeStackRegistry<JSCContextHandle>.defaultFrame(for: contextHandle)
    else {
      preconditionFailure("TypedArray buffer requires an open context default scope")
    }
    target.track(JSCOwnedValueHandle.adopting(bufferHandle))
    return JSCArrayBuffer(
      value: JSCValue(handle: bufferHandle, contextHandle: contextHandle))
  }
}
