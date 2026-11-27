// MARK: - Encoder contracts
//
// An encodable Swift value produces the engine's local value view through a
// `JSValueScope` window, and a converter (`JSValueEncoder`) does the same for
// its `SwiftType`.

/// A Swift value that can be encoded into a surface scope window.
public protocol JSValueEncodable: ~Copyable, SendableMetatype {
  func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value

  func tryEncodeSurface<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
}

extension JSValueEncodable where Self: ~Copyable {
  public func tryEncodeSurface<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    toSurfaceValue(in: context)
  }
}

/// A surface converter: `SwiftType` to the engine's local value view.
public protocol JSValueEncoder: ~Copyable, SendableMetatype {
  associatedtype SwiftType

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: SwiftType,
    in context: borrowing C
  ) -> C.Value

  static func tryEncode<C: JSValueScope & ~Copyable>(
    _ value: SwiftType,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
}

extension JSValueEncoder where Self: ~Copyable {
  public static func tryEncode<C: JSValueScope & ~Copyable>(
    _ value: SwiftType,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    encode(value, in: context)
  }
}

/// Both halves of the conversion contract.
public typealias JSValueCodable = JSValueDecodable & JSValueEncodable

/// A converter that decodes and encodes between Swift and the engine surface.
public typealias JSValueConverter = JSValueDecoder & JSValueEncoder

/// The default converter for a type that is itself surface-codeable.
public enum JSDefaultConverter<T: JSValueDecodable & JSValueEncodable>:
  JSValueDecoder, JSValueEncoder
{
  public typealias SwiftType = T

  public static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> T {
    T(value: value, in: context)
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode<C: JSValueScope & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) -> C.Value {
    value.toSurfaceValue(in: context)
  }

  public static func tryEncode<C: JSValueScope & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    try value.tryEncodeSurface(in: context)
  }
}

// MARK: - Global object composition
//
// Value-level conveniences shared by both scope kinds: they only forward to
// the scope's own global-object and global-property requirements.

extension JSInstantContext where Self: ~Copyable {
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing Value) -> R
  ) -> R {
    body(globalObjectValue())
  }

  /// Encode a Swift value through the surface witnesses and write it as a
  /// global property.
  public func setGlobalProperty<Value_: JSValueEncodable & ~Copyable>(
    _ value: borrowing Value_,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
  ) {
    let encoded = value.toSurfaceValue(in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSHostMemberAttributes = .none
  ) {
    _ = converter
    let encoded = C.encode(value, in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }
}

extension JSScope where Self: ~Copyable {
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing Value) -> R
  ) -> R {
    body(globalObjectValue())
  }

  /// Encode a Swift value through the surface witnesses and write it as a
  /// global property.
  public func setGlobalProperty<Value_: JSValueEncodable & ~Copyable>(
    _ value: borrowing Value_,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
  ) {
    let encoded = value.toSurfaceValue(in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSHostMemberAttributes = .none
  ) {
    _ = converter
    let encoded = C.encode(value, in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }
}

// MARK: - Built-in witnesses

extension Bool: JSValueEncodable {
  public func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeBoolean(self))
  }
}

extension Double: JSValueEncodable {
  public func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(self))
  }
}

extension Int32: JSValueEncodable {
  public func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(Double(self)))
  }
}

extension UInt32: JSValueEncodable {
  public func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(Double(self)))
  }
}

extension String: JSValueEncodable {
  public func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeString(self))
  }
}
