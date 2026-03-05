import JavaScriptCore

public enum JSValueConversionError: Error {
  case typeMismatch(expected: String, actual: JSType)
  case nonFiniteNumber(target: String)
  case outOfRange(target: String, value: Double)
  case nonInteger(target: String, value: Double)
}

public protocol JSValueDecodable: ~Copyable {
  init(value: borrowing JSValue, in context: isolated JSContext)
  static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext
  ) throws(JSValueConversionError) -> Self
}

extension JSValueDecodable {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> Self {
    Self(value: value, in: context)
  }
}

public protocol JSValueEncodable: ~Copyable {
  func toJSValue(in context: isolated JSContext) -> JSValue
  func tryEncode(in context: isolated JSContext) throws(JSValueConversionError) -> JSValue
}

extension JSValueEncodable {
  public func tryEncode(
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> JSValue {
    toJSValue(in: context)
  }
}

public typealias JSValueCodable = JSValueDecodable & JSValueEncodable

public protocol JSValueDecoder {
  associatedtype SwiftType

  static func decode(_ value: borrowing JSValue, in context: isolated JSContext) -> SwiftType
  static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext
  ) throws(JSValueConversionError) -> SwiftType
}

public protocol JSValueEncoder {
  associatedtype SwiftType

  static func tryEncode(
    _ value: SwiftType,
    in context: isolated JSContext
  ) throws(JSValueConversionError) -> JSValue
  static func encode(_ value: SwiftType, in context: isolated JSContext) -> JSValue
}

public typealias JSValueConverter = JSValueDecoder & JSValueEncoder

extension JSValueDecoder {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext
  ) throws(JSValueConversionError) -> SwiftType {
    decode(value, in: context)
  }
}

extension JSValueEncoder {
  public static func tryEncode(
    _ value: SwiftType,
    in context: isolated JSContext
  ) throws(JSValueConversionError) -> JSValue {
    encode(value, in: context)
  }
}

public enum JSDefaultConverter<T: JSValueCodable>: JSValueConverter {
  public static func decode(_ value: borrowing JSValue, in context: isolated JSContext = #isolation)
    -> T
  {
    T(value: value, in: context)
  }

  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode(_ value: T, in context: isolated JSContext = #isolation) -> JSValue {
    value.toJSValue(in: context)
  }

  public static func tryEncode(
    _ value: T,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> JSValue {
    try value.tryEncode(in: context)
  }
}

extension JSValue: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    self.init(ref: value.ref, ctx: context)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(ref: self.ref)
  }

  public func tryEncode(
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> JSValue {
    JSValue(ref: self.ref)
  }
}

extension JSValue {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> JSValue {
    JSValue(value: value, in: context)
  }
}

extension Bool: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    self = JSValueToBoolean(context.globalContextRef, value.ref)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(boolean: self)
  }
}

extension Bool {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> Bool {
    guard value.isBoolean else {
      throw .typeMismatch(expected: "boolean", actual: value.type)
    }
    return Bool(value: value, in: context)
  }
}

extension Double: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    var exception: JSValueRef?
    self = JSValueToNumber(context.globalContextRef, value.ref, &exception)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(number: self)
  }
}

extension Double {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> Double {
    guard value.isNumber else {
      throw .typeMismatch(expected: "number", actual: value.type)
    }
    return Double(value: value, in: context)
  }
}

extension Int32: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    let number = Double(value: value, in: context)
    self = Int32(number)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(number: self)
  }
}

extension Int32 {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> Int32 {
    let number = try Double.tryDecode(value, in: context)
    guard number.isFinite else {
      throw .nonFiniteNumber(target: "Int32")
    }
    guard floor(number) == number else {
      throw .nonInteger(target: "Int32", value: number)
    }
    let minValue = Double(Int32.min)
    let maxValue = Double(Int32.max)
    guard number >= minValue && number <= maxValue else {
      throw .outOfRange(target: "Int32", value: number)
    }
    return Int32(number)
  }
}

extension UInt32: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    let number = Double(value: value, in: context)
    self = UInt32(number)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(number: self)
  }
}

extension UInt32 {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> UInt32 {
    let number = try Double.tryDecode(value, in: context)
    guard number.isFinite else {
      throw .nonFiniteNumber(target: "UInt32")
    }
    guard floor(number) == number else {
      throw .nonInteger(target: "UInt32", value: number)
    }
    let minValue = 0.0
    let maxValue = Double(UInt32.max)
    guard number >= minValue && number <= maxValue else {
      throw .outOfRange(target: "UInt32", value: number)
    }
    return UInt32(number)
  }
}

extension String: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    var exception: JSValueRef?
    if let stringRef = JSValueToStringCopy(context.globalContextRef, value.ref, &exception) {
      defer { JSStringRelease(stringRef) }
      self = String(jsStringRef: stringRef)
      return
    }
    self = ""
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(string: self)
  }
}

extension String {
  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> String {
    guard value.isString else {
      throw .typeMismatch(expected: "string", actual: value.type)
    }
    return String(value: value, in: context)
  }
}

extension Never: JSValueEncodable {
  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    switch self {}
  }
}

extension JSValue {
  public func tryDecode<T: JSValueDecodable>(
    as type: T.Type = T.self,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func toBool(in context: isolated JSContext = #isolation) -> Bool {
    Bool(value: self, in: context)
  }

  public func toDouble(in context: isolated JSContext = #isolation) -> Double {
    Double(value: self, in: context)
  }

  public func toInt32(in context: isolated JSContext = #isolation) -> Int32 {
    Int32(value: self, in: context)
  }

  public func toUInt32(in context: isolated JSContext = #isolation) -> UInt32 {
    UInt32(value: self, in: context)
  }

  public func toString(in context: isolated JSContext = #isolation) -> String {
    String(value: self, in: context)
  }
}
