import Testing

@testable import SwiftyJavaScriptCore

enum ZeroOneBoolConverter: JSValueDecoder, JSValueEncoder {
  typealias SwiftType = Bool

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Bool {
    value.toNumber() != 0
  }

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: Bool,
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(value ? 1 : 0))
  }
}

struct FailingEncodeValue: JSValueEncodable {
  func toSurfaceValue<C: JSValueScope & ~Copyable>(in context: borrowing C) -> C.Value {
    context.persist(context.makeUndefined())
  }

  func tryEncodeSurface<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    _ = context
    throw .nonFiniteNumber(target: "FailingEncodeValue")
  }
}

struct ReturnPayload {
  let value: Double
}

enum ReturnPayloadEncoder: JSValueEncoder {
  typealias SwiftType = ReturnPayload

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: ReturnPayload,
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(value.value))
  }
}

enum FailurePayload: Error {
  case bad
}

enum FailurePayloadEncoder: JSValueEncoder {
  typealias SwiftType = FailurePayload

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: FailurePayload,
    in context: borrowing C
  ) -> C.Value {
    switch value {
    case .bad:
      return context.persist(context.makeString("bad"))
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

@JSValueAutoSerialization
struct MacroDefaultUser: Equatable {
  let name: String
  let age: Double
}

@JSValueAutoSerialization(MacroDelegatedUserDecoder.self, MacroDelegatedUserEncoder.self)
struct MacroDelegatedUser: Equatable {
  let score: Double
}

enum MacroDelegatedUserDecoder: JSValueDecoder {
  typealias SwiftType = MacroDelegatedUser

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> MacroDelegatedUser {
    _ = context
    return MacroDelegatedUser(score: value.toNumber())
  }
}

enum MacroDelegatedUserEncoder: JSValueEncoder {
  typealias SwiftType = MacroDelegatedUser

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: MacroDelegatedUser,
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(value.score))
  }
}

@JSValueAutoSerialization
struct MacroFieldOverrideUser: Equatable {
  let name: String
  @JSValueFieldCoding(ZeroOneBoolConverter.self)
  let active: Bool
}

@JSValueAutoSerialization
final class MacroSerializedClass: Equatable {
  let name: String
  @JSValueFieldCoding(ZeroOneBoolConverter.self)
  var active: Bool

  init(name: String, active: Bool) {
    self.name = name
    self.active = active
  }

  static func == (lhs: MacroSerializedClass, rhs: MacroSerializedClass) -> Bool {
    lhs.name == rhs.name && lhs.active == rhs.active
  }
}

@JSValueAutoSerialization
enum MacroStringEnum: Equatable {
  case pending
  case running
  case done
}

@JSValueAutoSerialization
enum MacroRawEnum: String, Equatable {
  case alpha = "A"
  case beta = "B"
}

@JSValueAutoSerialization
enum MacroAssociatedEnum: Equatable {
  case idle
  case count(Int32)
  case range(Int32, Int32)
  case user(id: Int32, name: String)
}

@JSValueAutoSerialization(tagKey: "type", payloadKey: "data")
enum MacroCustomKeyAssociatedEnum: Equatable {
  case idle
  case count(Int32)
  case user(id: Int32, name: String)
}

@JSValueAutoSerialization
enum MacroFlattenedAssociatedEnum: Equatable {
  case rgb(r: Int32, g: Int32, b: Int32)
  case named(name: String)
  case idle
}

@JSValueFieldCoding("enabled", ZeroOneBoolConverter.self)
@JSValueFieldCoding("pair.0", ZeroOneBoolConverter.self)
@JSValueFieldCoding("pair.1", ZeroOneBoolConverter.self)
@JSValueFieldCoding("flags.enabled", ZeroOneBoolConverter.self)
@JSValueAutoSerialization
enum MacroAssociatedOverrideEnum: Equatable {
  case enabled(Bool)
  case pair(Bool, Bool)
  case flags(id: Int32, enabled: Bool)
}
