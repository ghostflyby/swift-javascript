import Testing

@testable import SwiftyJavaScriptCore

enum ZeroOneBoolConverter: JSValueConverter {
  typealias SwiftType = Bool

  static func decode(_ value: borrowing JSValue, in context: borrowing JSCallbackContext) -> Bool {
    value.toDouble(in: context) != 0
  }

  static func encode(_ value: Bool, in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(number: value ? 1 : 0, in: context)
  }
}

struct FailingEncodeValue: JSValueEncodable {
  func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(undefinedIn: context)
  }

  func tryEncode(in context: borrowing JSCallbackContext) throws(JSValueConversionError) -> JSValue
  {
    throw .nonFiniteNumber(target: "FailingEncodeValue")
  }
}

struct ReturnPayload {
  let value: Double
}

enum ReturnPayloadEncoder: JSValueEncoder {
  typealias SwiftType = ReturnPayload

  static func encode(_ value: ReturnPayload, in context: borrowing JSCallbackContext) -> JSValue {
    JSValue(number: value.value, in: context)
  }
}

enum FailurePayload: Error {
  case bad
}

enum FailurePayloadEncoder: JSValueEncoder {
  typealias SwiftType = FailurePayload

  static func encode(_ value: FailurePayload, in context: borrowing JSCallbackContext) -> JSValue {
    switch value {
    case .bad:
      return JSValue(string: "bad", in: context)
    }
  }
}

struct CodableAddress: Codable, Equatable {
  let city: String
  let zip: Int
}

struct CodableUser: Codable, Equatable {
  let name: String
  let age: Int
  let active: Bool
  let tags: [String]
  let address: CodableAddress
}

@JSValueAutoConvertible
struct MacroDefaultUser: Equatable {
  let name: String
  let age: Double
}

@JSValueAutoConvertible(MacroDelegatedUserDecoder.self, MacroDelegatedUserEncoder.self)
struct MacroDelegatedUser: Equatable {
  let score: Double
}

enum MacroDelegatedUserDecoder: JSValueDecoder {
  typealias SwiftType = MacroDelegatedUser

  static func decode(_ value: borrowing JSValue, in context: borrowing JSCallbackContext)
    -> MacroDelegatedUser
  {
    MacroDelegatedUser(score: value.toDouble(in: context))
  }
}

enum MacroDelegatedUserEncoder: JSValueEncoder {
  typealias SwiftType = MacroDelegatedUser

  static func encode(_ value: MacroDelegatedUser, in context: borrowing JSCallbackContext)
    -> JSValue
  {
    JSValue(number: value.score, in: context)
  }
}

@JSValueAutoConvertible
struct MacroFieldOverrideUser: Equatable {
  let name: String
  @JSValueFieldCoding(ZeroOneBoolConverter.self)
  let active: Bool
}

@JSValueAutoConvertible
enum MacroStringEnum: Equatable {
  case pending
  case running
  case done
}

@JSValueAutoConvertible
enum MacroRawEnum: String, Equatable {
  case alpha = "A"
  case beta = "B"
}

@JSValueAutoConvertible
enum MacroAssociatedEnum: Equatable {
  case idle
  case count(Int32)
  case range(Int32, Int32)
  case user(id: Int32, name: String)
}

@JSValueAutoConvertible(tagKey: "type", payloadKey: "data")
enum MacroCustomKeyAssociatedEnum: Equatable {
  case idle
  case count(Int32)
  case user(id: Int32, name: String)
}

@JSValueAutoConvertible
enum MacroFlattenedAssociatedEnum: Equatable {
  case rgb(r: Int32, g: Int32, b: Int32)
  case named(name: String)
  case idle
}

@JSValueFieldCoding("enabled", ZeroOneBoolConverter.self)
@JSValueFieldCoding("pair.0", ZeroOneBoolConverter.self)
@JSValueFieldCoding("pair.1", ZeroOneBoolConverter.self)
@JSValueFieldCoding("flags.enabled", ZeroOneBoolConverter.self)
@JSValueAutoConvertible
enum MacroAssociatedOverrideEnum: Equatable {
  case enabled(Bool)
  case pair(Bool, Bool)
  case flags(id: Int32, enabled: Bool)
}
