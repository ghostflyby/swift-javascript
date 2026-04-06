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
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      Self(value: value, in: callbackContext)
    }
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self {
    Self(value: value, in: context)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: isolated JSEngineContext<E> = #isolation
  ) throws(JSValueConversionError) -> Self {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try Self.tryDecode(value, in: callbackContext)
    }
  }
}

public protocol JSValueEncodable: ~Copyable {
  func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E>
  func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
}

extension JSValueEncodable {
  public func toJSValue<E: JSEngine>(
    in context: isolated JSEngineContext<E> = #isolation
  ) -> JSValue<E> {
    context.withInstantContext { callbackContext in
      self.toJSValue(in: callbackContext)
    }
  }

  public func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    toJSValue(in: context)
  }

  public func tryEncode<E: JSEngine>(
    in context: isolated JSEngineContext<E> = #isolation
  ) throws(JSValueConversionError) -> JSValue<E> {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try self.tryEncode(in: callbackContext)
    }
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

  static func tryEncode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
  static func encode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  )
    -> JSValue<E>
}

public typealias JSValueConverter = JSValueDecoder & JSValueEncoder

extension JSValueDecoder {
  public static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>, in context: isolated JSEngineContext<E>
  )
    -> SwiftType
  {
    context.withInstantContext { callbackContext in
      Self.decode(value, in: callbackContext)
    }
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftType {
    decode(value, in: context)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: isolated JSEngineContext<E>
  ) throws(JSValueConversionError) -> SwiftType {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try Self.tryDecode(value, in: callbackContext)
    }
  }
}

extension JSValueEncoder {
  public static func encode<E: JSEngine>(
    _ value: SwiftType,
    in context: isolated JSEngineContext<E>
  )
    -> JSValue<E>
  {
    context.withInstantContext { callbackContext in
      Self.encode(value, in: callbackContext)
    }
  }

  public static func tryEncode<E: JSEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    encode(value, in: context)
  }

  public static func tryEncode<E: JSEngine>(
    _ value: SwiftType,
    in context: isolated JSEngineContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try Self.tryEncode(value, in: callbackContext)
    }
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

  public static func encode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  )
    -> JSValue<E>
  {
    value.toJSValue(in: context)
  }

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
