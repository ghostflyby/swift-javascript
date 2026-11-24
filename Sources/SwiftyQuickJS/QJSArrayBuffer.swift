import SwiftJavaScript

// MARK: - QuickJS buffers (S10)
//
// Mirrors the JavaScriptCore wrappers: real structs over the
// `QJSContextHandle` typed-array driver, with core holding the byte
// allocation/copy helpers and the `byteOffset` overlay. Failure semantics are
// unchanged: the driver clears the pending exception and releases the
// deallocator box it may have built, and the shared core helper releases the
// bytes it allocated exactly once because the engine never took them.

/// The QuickJS ArrayBuffer wrapper.
public struct QJSArrayBuffer: SwiftJavaScript.JSArrayBuffer, ~Copyable {
  public typealias Context = QJSContext
  public typealias ContextHandle = QJSContextHandle
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext

  package let value: QJSValue

  package init(value: consuming QJSValue) {
    self.value = value
  }

  public var contextHandle: QJSContextHandle { value.contextHandle }

  public borrowing func borrowHandle() -> QJSValueHandle {
    value.borrowHandle()
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
    self.init(value: context.anchorBorrowedHandle(value.borrowHandle()))
  }
}

/// The QuickJS TypedArray wrapper.
public struct QJSTypedArray: SwiftJavaScript.JSTypedArray, ~Copyable {
  public typealias Context = QJSContext
  public typealias ContextHandle = QJSContextHandle
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext
  public typealias Buffer = QJSArrayBuffer

  package let value: QJSValue

  package init(value: consuming QJSValue) {
    self.value = value
  }

  public var contextHandle: QJSContextHandle { value.contextHandle }

  public borrowing func borrowHandle() -> QJSValueHandle {
    value.borrowHandle()
  }

  public borrowing func withValue<R: ~Copyable>(_ body: (borrowing QJSValue) -> R) -> R {
    body(value)
  }

  // MARK: - Construction

  public init(kind: JSTypedArrayKind, length: Int, in context: borrowing QJSInstantContext) {
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
      value: context.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
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

    let bufferHandle = buffer.borrowHandle()
    let handle: QJSValueHandle?
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
      value: context.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
  }

  public init?(
    value: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) {
    guard value.isTypedArray(in: context) else {
      return nil
    }
    self.init(value: context.anchorBorrowedHandle(value.borrowHandle()))
  }

  // MARK: - Shape

  /// QuickJS returns a new reference to the backing buffer, so the wrapper
  /// adopts it into the context default scope exactly once.
  public var buffer: QJSArrayBuffer {
    guard
      let bufferHandle = contextHandle.typedArrayBufferForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray buffer")
    }
    guard
      let target = ScopeStackRegistry<QJSContextHandle>.defaultFrame(for: contextHandle)
    else {
      preconditionFailure("TypedArray buffer requires an open context default scope")
    }
    target.track(QJSOwnedValueHandle.adopting(bufferHandle))
    return QJSArrayBuffer(
      value: QJSValue(handle: bufferHandle, contextHandle: contextHandle))
  }
}
