/// An engine ArrayBuffer wrapper.
///
/// The concrete type is the engine's buffer (`JSCArrayBuffer`,
/// `QJSArrayBuffer`); core keeps the shared byte allocation/copy helpers
/// (`JSArrayBufferBytes.swift`) and the byte arithmetic below. Value-producing
/// operations return the engine's `Value` view.
public protocol JSArrayBuffer: ~Copyable {
  /// The context this buffer belongs to.
  associatedtype Context: JSContext
  /// The context identity every operation of this buffer is addressed
  /// through. Byte access needs the typed-array driver on top of the scope
  /// capabilities.
  associatedtype ContextHandle: JSScopeContextHandle & JSContextTypedArrayDriver
  where ContextHandle == Context.ContextHandle
  /// The value view `withValue` borrows.
  associatedtype Value: JSValue & ~Copyable
  where Value == Context.Value
  /// The scope buffers of this engine are created in.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

  var contextHandle: ContextHandle { get }

  /// The engine value handle behind this buffer.
  borrowing func borrowHandle() -> ContextHandle.ValueHandle

  /// Borrow the underlying value view. The buffer's arena keeps the reference
  /// alive, so `body` must not let the view outlive the call.
  borrowing func withValue<R: ~Copyable>(_ body: (borrowing Value) -> R) -> R

  // MARK: - Construction

  /// Create a zero-filled buffer of `byteLength` bytes on the calling window's
  /// arena.
  init(byteLength: Int, in context: borrowing InstantContext)

  /// Create a buffer that copies the given bytes.
  init(copying bytes: [UInt8], in context: borrowing InstantContext)

  /// Create a buffer that copies the given bytes.
  init(copying bytes: UnsafeRawBufferPointer, in context: borrowing InstantContext)

  /// Wrap an existing value that the engine classifies as an ArrayBuffer. The
  /// wrapped reference is anchored on the calling window's arena (`nil` when
  /// `value` is not an ArrayBuffer).
  init?(value: borrowing Value, in context: borrowing InstantContext)

  // MARK: - Bytes

  var byteLength: Int { get }

  /// A copy of the buffer's bytes.
  var bytes: [UInt8] { get }

  borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R

  borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R
}

// MARK: - Shared byte access
//
// Both engines address the same C-shaped driver, so the read/write surface is
// engine-independent. The engine only implements the construction inits and
// the identity accessors above.

extension JSArrayBuffer where Self: ~Copyable {
  public var byteLength: Int {
    guard let length = contextHandle.arrayBufferByteLengthForHandle(borrowHandle()) else {
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
    let access = contextHandle.arrayBufferBytesPtrForHandle(borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access ArrayBuffer bytes")
    }
    return body(UnsafeRawBufferPointer(start: access.bytes, count: byteLength))
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = contextHandle.arrayBufferBytesPtrForHandle(borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable ArrayBuffer bytes")
    }
    return body(UnsafeMutableRawBufferPointer(start: access.bytes, count: byteLength))
  }

  /// The number of `kind` elements that fit from `byteOffset` to the end of
  /// this buffer. Shared so both engines derive the same open-ended
  /// typed-array slice.
  package func remainingElementCount(
    from byteOffset: Int,
    kind: JSTypedArrayKind
  ) -> Int {
    (byteLength - byteOffset) / kind.bytesPerElement
  }
}
