/// An engine ArrayBuffer wrapper.
///
/// The concrete type is the engine's buffer (`JSCArrayBuffer`,
/// `QJSArrayBuffer`); core keeps the shared byte allocation/copy helpers
/// (`JSArrayBufferBytes.swift`) and the byte arithmetic below. Value-producing
/// operations return the engine's `Value` view. The engine implements the byte
/// access directly: only its own value type can turn the buffer into the
/// engine's byte pointer.
public protocol JSArrayBuffer: ~Copyable, ~Escapable {
  /// The context this buffer belongs to.
  associatedtype Context: JSContext
  /// The value view `withValue` borrows.
  associatedtype Value: JSValue & ~Copyable & ~Escapable
  where Value == Context.Value
  /// The scope buffers of this engine are created in.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

  /// Borrow the underlying value view. The buffer's arena keeps the reference
  /// alive, so `body` must not let the view outlive the call.
  borrowing func withValue<R: ~Copyable>(_ body: (borrowing Value) -> R) -> R

  // MARK: - Construction

  /// Create a zero-filled buffer of `byteLength` bytes on the calling window's
  /// arena.
  @_lifetime(borrow context)
  init(byteLength: Int, in context: borrowing InstantContext)

  /// Create a buffer that copies the given bytes.
  @_lifetime(borrow context)
  init(copying bytes: [UInt8], in context: borrowing InstantContext)

  /// Create a buffer that copies the given bytes.
  @_lifetime(borrow context)
  init(copying bytes: UnsafeRawBufferPointer, in context: borrowing InstantContext)

  /// Wrap an existing value that the engine classifies as an ArrayBuffer. The
  /// wrapped reference is anchored on the calling window's arena (`nil` when
  /// `value` is not an ArrayBuffer).
  @_lifetime(borrow context)
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

// MARK: - Shared byte arithmetic
//
// Byte access itself lives on the engine buffer (only the engine can reach its
// own byte pointer); core keeps the engine-independent arithmetic the engines
// share.

extension JSArrayBuffer where Self: ~Copyable & ~Escapable {
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
