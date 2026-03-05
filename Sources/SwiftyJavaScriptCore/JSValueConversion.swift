import JavaScriptCore

public protocol JSValueDecodable: ~Copyable {
  init(value: borrowing JSValue, in context: isolated JSContext)
}

public protocol JSValueEncodable: ~Copyable {
  func toJSValue(in context: isolated JSContext) -> JSValue
}

public typealias JSValueCodable = JSValueDecodable & JSValueEncodable

public protocol JSValueConverter {
  associatedtype SwiftType

  static func decode(_ value: borrowing JSValue, in context: isolated JSContext) -> SwiftType
  static func encode(_ value: SwiftType, in context: isolated JSContext) -> JSValue
}

public enum JSDefaultConverter<T: JSValueCodable>: JSValueConverter {
  public static func decode(_ value: borrowing JSValue, in context: isolated JSContext = #isolation)
    -> T
  {
    T(value: value, in: context)
  }

  public static func encode(_ value: T, in context: isolated JSContext = #isolation) -> JSValue {
    value.toJSValue(in: context)
  }
}

extension JSValue: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    self.init(ref: value.ref, ctx: context)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(ref: self.ref)
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

extension Double: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    var exception: JSValueRef?
    self = JSValueToNumber(context.globalContextRef, value.ref, &exception)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(number: self)
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

extension UInt32: JSValueCodable {
  public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
    let number = Double(value: value, in: context)
    self = UInt32(number)
  }

  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    JSValue(number: self)
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

extension Never: JSValueEncodable {
  public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
    switch self {}
  }
}

extension JSValue {
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
