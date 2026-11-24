// Decoder witnesses for the built-in Swift value types.
//
// Their generic bound is the fixed surface signature: the `JSInstantContext`
// window and its own `Value` view.
// Encoder witnesses (`JSValueEncodable`) live in
// `JSValueConversionSurfaceEncoders.swift`.

extension Bool: JSValueDecodable {
  public init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self = value.toBoolean()
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Bool {
    _ = context
    guard value.isBoolean() else {
      throw .typeMismatch(expected: "boolean", actual: value.type())
    }
    return value.toBoolean()
  }
}

extension Double: JSValueDecodable {
  public init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self = value.toNumber()
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Double {
    _ = context
    guard value.isNumber() else {
      throw .typeMismatch(expected: "number", actual: value.type())
    }
    return value.toNumber()
  }
}

extension Int32: JSValueDecodable {
  public init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self = Int32(value.toNumber())
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Int32 {
    let number = try Double.tryDecode(value, in: context)
    try validateIntegerDecode(
      number,
      target: "Int32",
      minValue: Double(Int32.min),
      maxValue: Double(Int32.max)
    )
    return Int32(number)
  }
}

extension UInt32: JSValueDecodable {
  public init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self = UInt32(value.toNumber())
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> UInt32 {
    let number = try Double.tryDecode(value, in: context)
    try validateIntegerDecode(
      number,
      target: "UInt32",
      minValue: 0.0,
      maxValue: Double(UInt32.max)
    )
    return UInt32(number)
  }
}

extension String: JSValueDecodable {
  public init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = context
    self = value.toString()
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> String {
    _ = context
    guard value.isString() else {
      throw .typeMismatch(expected: "string", actual: value.type())
    }
    return value.toString()
  }
}

/// Uninhabited decode: `Never` cannot be produced from a JavaScript value.
/// Constructing it traps; `tryDecode` reports the type mismatch instead.
extension Never: JSValueDecodable {
  public init<C: JSInstantContext & ~Copyable>(
    value: borrowing C.Value,
    in context: borrowing C
  ) {
    _ = value
    _ = context
    fatalError("Never cannot be decoded from a JavaScript value")
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Never {
    _ = context
    throw .typeMismatch(expected: "Never", actual: value.type())
  }
}

// MARK: - Integer decode validation

/// Validate a decoded `Double` as an integer of the requested target type.
package func validateIntegerDecode(
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
