/// An engine TypedArray wrapper.
///
/// The concrete type is the engine's typed array (`JSCTypedArray`,
/// `QJSTypedArray`); core keeps the whole-buffer convenience initializer.
/// Shape and byte access are implemented by the engine: only its own value type
/// can read the array's kind/offset and overlay `byteOffset` on its backing
/// pointer.
public protocol JSTypedArray: ~Copyable {
  /// The context this typed array belongs to.
  associatedtype Context: JSContext
  associatedtype Value: JSValue & ~Copyable
  where Value == Context.Value
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext
  /// The buffer type this array views.
  associatedtype Buffer: JSArrayBuffer & ~Copyable
  where Buffer == Context.ArrayBuffer

  /// Borrow the underlying value view. The typed array's arena keeps the
  /// reference alive, so `body` must not let the view outlive the call.
  borrowing func withValue<R: ~Copyable>(_ body: (borrowing Value) -> R) -> R

  // MARK: - Construction

  /// Create a zero-filled typed array of `length` elements.
  init(kind: JSTypedArrayKind, length: Int, in context: borrowing InstantContext)

  /// Create a typed array view over an existing buffer.
  ///
  /// `length == nil` covers the rest of the buffer from `byteOffset`. The
  /// element count is computed in core, so both engines derive the same slice
  /// for a non-zero offset.
  init(
    kind: JSTypedArrayKind,
    buffer: borrowing Buffer,
    byteOffset: Int,
    length: Int?,
    in context: borrowing InstantContext
  )

  /// Wrap an existing value that the engine classifies as a typed array. The
  /// wrapped reference is anchored on the calling window's arena (`nil` when
  /// `value` is not a typed array).
  init?(value: borrowing Value, in context: borrowing InstantContext)

  // MARK: - Shape

  var kind: JSTypedArrayKind { get }
  var length: Int { get }
  var byteLength: Int { get }
  var byteOffset: Int { get }

  /// The buffer this array views. The engine adopts the engine-returned buffer
  /// reference into the context default scope once.
  var buffer: Buffer { get }

  // MARK: - Bytes

  /// A copy of this array's bytes (the buffer slice, not the whole buffer).
  var bytes: [UInt8] { get }

  borrowing func withUnsafeBytes<R: ~Copyable>(_ body: (UnsafeRawBufferPointer) -> R) -> R

  borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R
}

// MARK: - Shared construction convenience
//
// The engine reports kind/length/byteLength/byteOffset and the bytes itself;
// core only supplies the argument completion that needs no engine access.

extension JSTypedArray where Self: ~Copyable {
  /// Create a typed array that views the whole buffer.
  public init(
    kind: JSTypedArrayKind,
    buffer: borrowing Buffer,
    in context: borrowing InstantContext
  ) {
    self.init(kind: kind, buffer: buffer, byteOffset: 0, length: nil, in: context)
  }
}
