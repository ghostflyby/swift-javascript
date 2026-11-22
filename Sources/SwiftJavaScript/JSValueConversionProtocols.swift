/// Driver face required by the shared conversion protocol signatures.
///
/// Each protocol declares one generic requirement covering every conformer;
/// the strongest built-in conformer (`JSCodableValueConverter`) needs property
/// and invocation operations, so the shared surface is their union. Primitive
/// conformers use only the runtime subset but must match the same signature.
public typealias JSValueConversionEngine = JSEnginePropertyDriver & JSEngineInvocationDriver

public protocol JSValueDecodable: ~Copyable {
  init<E: JSValueConversionEngine>(
    value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>)
  static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self
}

extension JSValueDecodable {
  public init<E: JSContextEngine & JSValueConversionEngine>(
    value: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      Self(value: value, in: callbackContext)
    }
  }

  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self {
    Self(value: value, in: context)
  }

  public static func tryDecode<E: JSContextEngine & JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> Self {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try Self.tryDecode(value, in: callbackContext)
    }
  }
}

public protocol JSValueEncodable: ~Copyable {
  func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E>
  func tryEncode<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
}

extension JSValueEncodable {
  public func toJSValue<E: JSContextEngine & JSValueConversionEngine>(
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    context.withInstantContext { callbackContext in
      let value = self.toJSValue(in: callbackContext)
      // The witness scope closes before the caller receives the value: any
      // reference it still owns must move to the context default scope so the
      // returned view stays valid beyond this synchronous window.
      return callbackContext.anchorEscapingValue(value)
    }
  }

  public func tryEncode<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    toJSValue(in: context)
  }

  public func tryEncode<E: JSContextEngine & JSValueConversionEngine>(
    in context: isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> JSValue<E> {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      let value = try self.tryEncode(in: callbackContext)
      return callbackContext.anchorEscapingValue(value)
    }
  }
}

public typealias JSValueCodable = JSValueDecodable & JSValueEncodable

public protocol JSValueDecoder {
  associatedtype SwiftType

  static func decode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>
  )
    -> SwiftType
  static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftType
}

public protocol JSValueEncoder {
  associatedtype SwiftType

  static func tryEncode<E: JSValueConversionEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
  static func encode<E: JSValueConversionEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  )
    -> JSValue<E>
}

public typealias JSValueConverter = JSValueDecoder & JSValueEncoder

extension JSValueDecoder {
  public static func decode<E: JSContextEngine & JSValueConversionEngine>(
    _ value: borrowing JSValue<E>, in context: isolated JSContext<E>
  )
    -> SwiftType
  {
    context.withInstantContext { callbackContext in
      Self.decode(value, in: callbackContext)
    }
  }

  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftType {
    decode(value, in: context)
  }

  public static func tryDecode<E: JSContextEngine & JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: isolated JSContext<E>
  ) throws(JSValueConversionError) -> SwiftType {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try Self.tryDecode(value, in: callbackContext)
    }
  }
}

extension JSValueEncoder {
  public static func encode<E: JSContextEngine & JSValueConversionEngine>(
    _ value: SwiftType,
    in context: isolated JSContext<E>
  )
    -> JSValue<E>
  {
    context.withInstantContext { callbackContext in
      let encoded = Self.encode(value, in: callbackContext)
      // Same escape boundary as `JSValueEncodable.toJSValue(in:)`: anchor the
      // returned view in the context default scope before the witness drains.
      return callbackContext.anchorEscapingValue(encoded)
    }
  }

  public static func tryEncode<E: JSValueConversionEngine>(
    _ value: SwiftType,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    encode(value, in: context)
  }

  public static func tryEncode<E: JSContextEngine & JSValueConversionEngine>(
    _ value: SwiftType,
    in context: isolated JSContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      let encoded = try Self.tryEncode(value, in: callbackContext)
      return callbackContext.anchorEscapingValue(encoded)
    }
  }
}

public enum JSDefaultConverter<T: JSValueCodable>:
  JSValueConverter
{
  public static func decode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>, in context: borrowing JSInstantContext<E>
  )
    -> T
  {
    T(value: value, in: context)
  }

  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode<E: JSValueConversionEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  )
    -> JSValue<E>
  {
    value.toJSValue(in: context)
  }

  public static func tryEncode<E: JSValueConversionEngine>(
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
