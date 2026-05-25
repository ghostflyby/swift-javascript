import Testing

@testable import SwiftyJavaScriptCore

enum ZeroOneBoolConverter: JSValueConverter {
  typealias SwiftType = Bool

  static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    value.toDouble(in: context) != 0
  }

  static func encode<E: JSEngine>(
    _ value: Bool,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    JSValue(number: value ? 1 : 0, in: context)
  }
}

struct FailingEncodeValue: JSValueEncodable {
  func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    JSValue(undefinedIn: context)
  }

  func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    _ = context
    throw .nonFiniteNumber(target: "FailingEncodeValue")
  }

}

struct ReturnPayload {
  let value: Double
}

enum ReturnPayloadEncoder: JSValueEncoder {
  typealias SwiftType = ReturnPayload

  static func encode<E: JSEngine>(
    _ value: ReturnPayload,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    JSValue(number: value.value, in: context)
  }
}

enum FailurePayload: Error {
  case bad
}

enum FailurePayloadEncoder: JSValueEncoder {
  typealias SwiftType = FailurePayload

  static func encode<E: JSEngine>(
    _ value: FailurePayload,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
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

  static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> MacroDelegatedUser {
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    return decode(
      JSValue<JavaScriptCoreEngine>(
        handleValue: unsafeBitCast(
          value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self),
        in: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
  }

  static func decode(
    _ value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  )
    -> MacroDelegatedUser
  {
    MacroDelegatedUser(score: value.toDouble(in: context))
  }
}

enum MacroDelegatedUserEncoder: JSValueEncoder {
  typealias SwiftType = MacroDelegatedUser

  static func encode<E: JSEngine>(
    _ value: MacroDelegatedUser,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    let encoded = encode(
      value,
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
    return JSValue<E>(
      handleValue: unsafeBitCast(encoded.takeHandle(), to: JSValueHandle<E>.self),
      in: context.driverContextHandle)
  }

  static func encode(
    _ value: MacroDelegatedUser, in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  )
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(number: value.score, in: context)
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
