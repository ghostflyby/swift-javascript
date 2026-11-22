extension Bool: JSValueDecodable, JSValueEncodable {
  public init<E: JSValueConversionEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self = context.toBoolean(value)
  }

  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    context.persist(context.makeBoolean(self))
  }
}

extension Bool {
  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Bool {
    guard value.isBoolean(in: context) else {
      throw .typeMismatch(expected: "boolean", actual: value.type(in: context))
    }
    return Bool(value: value, in: context)
  }
}

extension Double: JSValueDecodable, JSValueEncodable {
  public init<E: JSValueConversionEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self = context.toNumber(value)
  }

  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    context.persist(context.makeNumber(self))
  }
}

extension Double {
  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Double {
    guard value.isNumber(in: context) else {
      throw .typeMismatch(expected: "number", actual: value.type(in: context))
    }
    return Double(value: value, in: context)
  }
}

extension Int32: JSValueDecodable, JSValueEncodable {
  public init<E: JSValueConversionEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    let number = Double(value: value, in: context)
    self = Int32(number)
  }

  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    context.persist(context.makeNumber(Double(self)))
  }
}

extension Int32 {
  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
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

extension UInt32: JSValueDecodable, JSValueEncodable {
  public init<E: JSValueConversionEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    let number = Double(value: value, in: context)
    self = UInt32(number)
  }

  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    context.persist(context.makeNumber(Double(self)))
  }
}

extension UInt32 {
  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
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

extension String: JSValueDecodable, JSValueEncodable {
  public init<E: JSValueConversionEngine>(
    value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self = context.toString(value)
  }

  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    context.persist(context.makeString(self))
  }
}

extension String {
  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> String {
    guard value.isString(in: context) else {
      throw .typeMismatch(expected: "string", actual: value.type(in: context))
    }
    return String(value: value, in: context)
  }
}

extension Never: JSValueEncodable {
  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    _ = context
    switch self {}
  }
}

extension JSValue where E: JSValueConversionEngine {
  public func tryDecode<T: JSValueDecodable>(
    as type: T.Type = T.self,
    in context: isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> T where E: JSContextEngine {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func toBool(in context: isolated JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    Bool(value: self, in: context)
  }

  public func toDouble(in context: isolated JSContext<E> = #isolation) -> Double
  where E: JSContextEngine {
    Double(value: self, in: context)
  }

  public func toInt32(in context: isolated JSContext<E> = #isolation) -> Int32
  where E: JSContextEngine {
    Int32(value: self, in: context)
  }

  public func toUInt32(in context: isolated JSContext<E> = #isolation) -> UInt32
  where E: JSContextEngine {
    UInt32(value: self, in: context)
  }

  public func toString(in context: isolated JSContext<E> = #isolation) -> String
  where E: JSContextEngine {
    String(value: self, in: context)
  }

  public func toBool(in context: borrowing JSInstantContext<E>) -> Bool {
    Bool(value: self, in: context)
  }

  public func toDouble(in context: borrowing JSInstantContext<E>) -> Double {
    Double(value: self, in: context)
  }

  public func toInt32(in context: borrowing JSInstantContext<E>) -> Int32 {
    Int32(value: self, in: context)
  }

  public func toUInt32(in context: borrowing JSInstantContext<E>) -> UInt32 {
    UInt32(value: self, in: context)
  }

  public func toString(in context: borrowing JSInstantContext<E>) -> String {
    String(value: self, in: context)
  }
}
