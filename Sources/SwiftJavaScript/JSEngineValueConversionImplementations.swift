extension Bool: JSValueDecodable, JSValueEncodable {
  public init<E: JSEngine>(
    value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    self = context.toBoolean(value)
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    context.makeBoolean(self)
  }
}

extension Bool {
  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> Bool {
    guard value.isBoolean(in: context) else {
      throw .typeMismatch(expected: "boolean", actual: value.type(in: context))
    }
    return Bool(value: value, in: context)
  }
}

extension Double: JSValueDecodable, JSValueEncodable {
  public init<E: JSEngine>(
    value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    self = context.toNumber(value)
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    context.makeNumber(self)
  }
}

extension Double {
  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> Double {
    guard value.isNumber(in: context) else {
      throw .typeMismatch(expected: "number", actual: value.type(in: context))
    }
    return Double(value: value, in: context)
  }
}

extension Int32: JSValueDecodable, JSValueEncodable {
  public init<E: JSEngine>(
    value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    let number = Double(value: value, in: context)
    self = Int32(number)
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    context.makeNumber(self)
  }
}

extension Int32 {
  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
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
  public init<E: JSEngine>(
    value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    let number = Double(value: value, in: context)
    self = UInt32(number)
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    context.makeNumber(self)
  }
}

extension UInt32 {
  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
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
  public init<E: JSEngine>(
    value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    self = context.toString(value)
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    context.makeString(self)
  }
}

extension String {
  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> String {
    guard value.isString(in: context) else {
      throw .typeMismatch(expected: "string", actual: value.type(in: context))
    }
    return String(value: value, in: context)
  }
}

extension Never: JSValueEncodable {
  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    _ = context
    switch self {}
  }
}

extension JSEngineValue {
  public func tryDecode<T: JSValueDecodable>(
    as type: T.Type = T.self,
    in context: isolated JSEngineContext<E> = #isolation
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func toBool(in context: isolated JSEngineContext<E> = #isolation) -> Bool {
    Bool(value: self, in: context)
  }

  public func toDouble(in context: isolated JSEngineContext<E> = #isolation) -> Double {
    Double(value: self, in: context)
  }

  public func toInt32(in context: isolated JSEngineContext<E> = #isolation) -> Int32 {
    Int32(value: self, in: context)
  }

  public func toUInt32(in context: isolated JSEngineContext<E> = #isolation) -> UInt32 {
    UInt32(value: self, in: context)
  }

  public func toString(in context: isolated JSEngineContext<E> = #isolation) -> String {
    String(value: self, in: context)
  }

  public func toBool(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    Bool(value: self, in: context)
  }

  public func toDouble(in context: borrowing JSEngineInstantContext<E>) -> Double {
    Double(value: self, in: context)
  }

  public func toInt32(in context: borrowing JSEngineInstantContext<E>) -> Int32 {
    Int32(value: self, in: context)
  }

  public func toUInt32(in context: borrowing JSEngineInstantContext<E>) -> UInt32 {
    UInt32(value: self, in: context)
  }

  public func toString(in context: borrowing JSEngineInstantContext<E>) -> String {
    String(value: self, in: context)
  }
}
