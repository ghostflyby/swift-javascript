/// A Swift value that can be decoded from an engine value inside a scope
/// window.
///
/// Signature: `init<C: JSInstantContext & ~Copyable>(value: borrowing C.Value,
/// in context: borrowing C)`.
///
/// Like every conversion entry, decoding is rooted at the scope window: the
/// value is always the window's own `Value`. Relationships between a window's
/// types are stated once, on `JSContext`, so a generic window resolves them
/// through its context; a signature taking an unrelated value view would need
/// the window pinned to its context in both directions.
public protocol JSValueDecodable: ~Copyable {
  init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  )

  static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self
}

extension JSValueDecodable where Self: ~Copyable {
  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self {
    Self(value: value, in: context)
  }
}

/// A converter that decodes an engine value into `SwiftType`.
///
/// Signature: `decode`/`tryDecode<C: JSInstantContext & ~Copyable>(
/// _ value: borrowing C.Value, in context: borrowing C)`.
public protocol JSValueDecoder: ~Copyable {
  associatedtype SwiftType

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> SwiftType

  static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> SwiftType
}

extension JSValueDecoder where Self: ~Copyable {
  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> SwiftType {
    decode(value, in: context)
  }
}
