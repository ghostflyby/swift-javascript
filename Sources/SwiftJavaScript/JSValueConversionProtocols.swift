public protocol JSValueDecodable: ~Copyable {
  init<E: JSEngine>(value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>)
  static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self
}

extension JSValueDecodable {
  public init<E: JSEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    let instantContext = JSInstantContext<E>(context: context)
    self = Self(value: value, in: instantContext)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self {
    Self(value: value, in: context)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> Self {
    let instantContext = JSInstantContext<E>(context: context)
    return try Self.tryDecode(value, in: instantContext)
  }
}

public protocol JSValueEncodable: ~Copyable, ~Escapable {
  @_lifetime(borrow context)
  func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E>
  @_lifetime(borrow context)
  func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
}

extension JSValueEncodable {
  @_lifetime(borrow context)
  public func toJSValue<E: JSEngine>(
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    let instantContext = JSInstantContext<E>(context: context)
    let value = toJSValue(in: instantContext)
    return JSValue(retaining: value)
  }

  @_lifetime(borrow context)
  public func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    toJSValue(in: context)
  }

  @_lifetime(borrow context)
  public func tryEncode<E: JSEngine>(
    in context: borrowing isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> JSValue<E> {
    let instantContext = JSInstantContext<E>(context: context)
    let value = try tryEncode(in: instantContext)
    return JSValue(retaining: value)
  }
}

public typealias JSValueCodable = JSValueDecodable & JSValueEncodable

public protocol JSValueDecoder {
  associatedtype SwiftType

  static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>
  )
    -> SwiftType
  static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftType
}

public protocol JSValueEncoder {
  associatedtype SwiftType

  @_lifetime(borrow context)
  static func tryEncode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
  @_lifetime(borrow context)
  static func encode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  )
    -> JSValue<E>
}

public typealias JSValueConverter = JSValueDecoder & JSValueEncoder

extension JSValueDecoder {
  public static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>, in context: borrowing isolated JSContext<E>
  )
    -> SwiftType
  {
    let instantContext = JSInstantContext<E>(context: context)
    return Self.decode(value, in: instantContext)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftType {
    decode(value, in: context)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E>
  ) throws(JSValueConversionError) -> SwiftType {
    let instantContext = JSInstantContext<E>(context: context)
    return try Self.tryDecode(value, in: instantContext)
  }
}

extension JSValueEncoder {
  @_lifetime(borrow context)
  public static func encode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing isolated JSContext<E>
  )
    -> JSValue<E>
  {
    let instantContext = JSInstantContext<E>(context: context)
    let value = Self.encode(value, in: instantContext)
    return JSValue(retaining: value)
  }

  @_lifetime(borrow context)
  public static func tryEncode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    encode(value, in: context)
  }

  @_lifetime(borrow context)
  public static func tryEncode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing isolated JSContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    let instantContext = JSInstantContext<E>(context: context)
    let value = try Self.tryEncode(value, in: instantContext)
    return JSValue(retaining: value)
  }
}

public enum JSDefaultConverter<T: JSValueCodable>:
  JSValueConverter
{
  public static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>
  )
    -> T
  {
    T(value: value, in: context)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  @_lifetime(borrow context)
  public static func encode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  )
    -> JSValue<E>
  {
    value.toJSValue(in: context)
  }

  @_lifetime(borrow context)
  public static func tryEncode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try value.tryEncode(in: context)
  }
}

public func validateIntegerDecode(
  _ number: Double,
  target: String,
  minValue: Double,
  maxValue: Double
) throws(JSValueConversionError) {
  guard number.isFinite else {
    throw .nonFiniteNumber(target: target)
  }
  guard number.rounded(.towardZero) == number else {
    throw .nonInteger(target: target, value: number)
  }
  guard number >= minValue && number <= maxValue else {
    throw .outOfRange(target: target, value: number)
  }
}
