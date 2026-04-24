import SwiftyJavaScriptCore

package enum ZeroOneBoolConverter: JSValueConverter {
  package typealias SwiftType = Bool

  package static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    return decode(
      JSValue<JavaScriptCoreEngine>(
        handleValue: unsafeBitCast(
          value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
  }

  @_lifetime(borrow context)
  package static func encode<E: JSEngine>(
    _ value: Bool,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(number: value ? 1 : 0, in: jscContext).takeHandle()
    }
  }

  package static func decode(
    _ value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> Bool {
    value.toDouble(in: context) != 0
  }

  @_lifetime(borrow context)
  package static func encode(
    _ value: Bool,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> JSValue<JavaScriptCoreEngine> {
    JSValue(number: value ? 1 : 0, in: context)
  }
}

package struct FailingEncodeValue: JSValueEncodable {
  package init() {}

  @_lifetime(borrow context)
  package func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(undefinedIn: jscContext).takeHandle()
    }
  }

  @_lifetime(borrow context)
  package func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> JSValue<JavaScriptCoreEngine>
  {
    JSValue(undefinedIn: context)
  }

  @_lifetime(borrow context)
  package func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    _ = context
    throw .nonFiniteNumber(target: "FailingEncodeValue")
  }

  @_lifetime(borrow context)
  package func tryEncode(
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> JSValue<JavaScriptCoreEngine> {
    _ = context
    throw .nonFiniteNumber(target: "FailingEncodeValue")
  }
}

package struct ReturnPayload {
  package let value: Double

  package init(value: Double) {
    self.value = value
  }
}

package enum ReturnPayloadEncoder: JSValueEncoder {
  package typealias SwiftType = ReturnPayload

  @_lifetime(borrow context)
  package static func encode<E: JSEngine>(
    _ value: ReturnPayload,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(number: value.value, in: jscContext).takeHandle()
    }
  }

  @_lifetime(borrow context)
  package static func encode(
    _ value: ReturnPayload,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> JSValue<JavaScriptCoreEngine> {
    JSValue(number: value.value, in: context)
  }
}

package enum FailurePayload: Error {
  case bad
}

package enum FailurePayloadEncoder: JSValueEncoder {
  package typealias SwiftType = FailurePayload

  @_lifetime(borrow context)
  package static func encode<E: JSEngine>(
    _ value: FailurePayload,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(string: "bad", in: jscContext).takeHandle()
    }
  }

  @_lifetime(borrow context)
  package static func encode(
    _ value: FailurePayload,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> JSValue<JavaScriptCoreEngine> {
    switch value {
    case .bad:
      return JSValue(string: "bad", in: context)
    }
  }
}

package struct CodableAddress: Codable, Equatable {
  package let city: String
  package let zip: Int

  package init(city: String, zip: Int) {
    self.city = city
    self.zip = zip
  }
}

package struct CodableUser: Codable, Equatable {
  package let name: String
  package let age: Int
  package let active: Bool
  package let tags: [String]
  package let address: CodableAddress

  package init(name: String, age: Int, active: Bool, tags: [String], address: CodableAddress) {
    self.name = name
    self.age = age
    self.active = active
    self.tags = tags
    self.address = address
  }
}

@JSValueAutoSerialization
package struct MacroDefaultUser: Equatable {
  package let name: String
  package let age: Double

  package init(name: String, age: Double) {
    self.name = name
    self.age = age
  }
}

@JSValueAutoSerialization(MacroDelegatedUserDecoder.self, MacroDelegatedUserEncoder.self)
package struct MacroDelegatedUser: Equatable {
  package let score: Double

  package init(score: Double) {
    self.score = score
  }
}

package enum MacroDelegatedUserDecoder: JSValueDecoder {
  package typealias SwiftType = MacroDelegatedUser

  package static func decode<E: JSEngine>(
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
          value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
  }

  package static func decode(
    _ value: borrowing JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> MacroDelegatedUser {
    MacroDelegatedUser(score: value.toDouble(in: context))
  }
}

package enum MacroDelegatedUserEncoder: JSValueEncoder {
  package typealias SwiftType = MacroDelegatedUser

  @_lifetime(borrow context)
  package static func encode<E: JSEngine>(
    _ value: MacroDelegatedUser,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    bridgeJavaScriptCoreValue(in: context) { jscContext in
      JSValue(number: value.score, in: jscContext).takeHandle()
    }
  }

  @_lifetime(borrow context)
  package static func encode(
    _ value: MacroDelegatedUser,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> JSValue<JavaScriptCoreEngine> {
    JSValue(number: value.score, in: context)
  }
}

@JSValueAutoSerialization
package struct MacroFieldOverrideUser: Equatable {
  package let name: String
  @JSValueFieldCoding(ZeroOneBoolConverter.self)
  package let active: Bool

  package init(name: String, active: Bool) {
    self.name = name
    self.active = active
  }
}

@JSValueAutoSerialization
package final class MacroSerializedClass: Equatable {
  package let name: String
  @JSValueFieldCoding(ZeroOneBoolConverter.self)
  package var active: Bool

  package init(name: String, active: Bool) {
    self.name = name
    self.active = active
  }

  package static func == (lhs: MacroSerializedClass, rhs: MacroSerializedClass) -> Bool {
    lhs.name == rhs.name && lhs.active == rhs.active
  }
}

@JSValueAutoSerialization
package enum MacroStringEnum: Equatable {
  case pending
  case running
  case done
}

@JSValueAutoSerialization
package enum MacroRawEnum: String, Equatable {
  case alpha = "A"
  case beta = "B"
}

@JSValueAutoSerialization
package enum MacroAssociatedEnum: Equatable {
  case idle
  case count(Int32)
  case range(Int32, Int32)
  case user(id: Int32, name: String)
}

@JSValueAutoSerialization(tagKey: "type", payloadKey: "data")
package enum MacroCustomKeyAssociatedEnum: Equatable {
  case idle
  case count(Int32)
  case user(id: Int32, name: String)
}

@JSValueAutoSerialization
package enum MacroFlattenedAssociatedEnum: Equatable {
  case rgb(r: Int32, g: Int32, b: Int32)
  case named(name: String)
  case idle
}

@JSValueFieldCoding("enabled", ZeroOneBoolConverter.self)
@JSValueFieldCoding("pair.0", ZeroOneBoolConverter.self)
@JSValueFieldCoding("pair.1", ZeroOneBoolConverter.self)
@JSValueFieldCoding("flags.enabled", ZeroOneBoolConverter.self)
@JSValueAutoSerialization
package enum MacroAssociatedOverrideEnum: Equatable {
  case enabled(Bool)
  case pair(Bool, Bool)
  case flags(id: Int32, enabled: Bool)
}
