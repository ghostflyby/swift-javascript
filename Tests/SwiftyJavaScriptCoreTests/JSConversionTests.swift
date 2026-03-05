import Testing

@testable import SwiftyJavaScriptCore

enum ZeroOneBoolConverter: JSValueConverter {
  typealias SwiftType = Bool

  static func decode(_ value: borrowing JSValue, in context: isolated JSContext) -> Bool {
    value.toDouble(in: context) != 0
  }

  static func encode(_ value: Bool, in context: isolated JSContext) -> JSValue {
    JSValue(number: value ? 1 : 0, in: context)
  }
}

struct FailingEncodeValue: JSValueEncodable {
  func toJSValue(in context: isolated JSContext) -> JSValue {
    JSValue(undefinedIn: context)
  }

  func tryEncode(in context: isolated JSContext) throws(JSValueConversionError) -> JSValue {
    throw .nonFiniteNumber(target: "FailingEncodeValue")
  }
}

struct ReturnPayload {
  let value: Double
}

enum ReturnPayloadEncoder: JSValueEncoder {
  typealias SwiftType = ReturnPayload

  static func encode(_ value: ReturnPayload, in context: isolated JSContext) -> JSValue {
    JSValue(number: value.value, in: context)
  }
}

enum FailurePayload: Error {
  case bad
}

enum FailurePayloadEncoder: JSValueEncoder {
  typealias SwiftType = FailurePayload

  static func encode(_ value: FailurePayload, in context: isolated JSContext) -> JSValue {
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

  static func decode(_ value: borrowing JSValue, in context: isolated JSContext)
    -> MacroDelegatedUser
  {
    MacroDelegatedUser(score: value.toDouble(in: context))
  }
}

enum MacroDelegatedUserEncoder: JSValueEncoder {
  typealias SwiftType = MacroDelegatedUser

  static func encode(_ value: MacroDelegatedUser, in context: isolated JSContext) -> JSValue {
    JSValue(number: value.score, in: context)
  }
}

@JSValueAutoConvertible
struct MacroFieldOverrideUser: Equatable {
  let name: String
  @JSValueFieldCoding(ZeroOneBoolConverter.self)
  let active: Bool
}

@Test func builtinCodableRoundtrip() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let key = JSStringManaged("number")
    global.setProperty(42.5, forKey: key, in: context)

    let decoded = global.getProperty(
      forKey: key, using: JSDefaultConverter<Double>.self, in: context)
    #expect(decoded == 42.5)

    let scriptValue = context.evaluateScript("'abc'")
    switch consume scriptValue {
    case .value(let value):
      #expect(value.toString(in: context) == "abc")
    case .exception:
      Issue.record("Expected string result")
    }
  }
}

@Test func converterOverrideForPropertyReadWrite() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let key = JSStringManaged("flag")

    global.setProperty(true, forKey: key, using: ZeroOneBoolConverter.self, in: context)

    let raw = global.getProperty(forKey: key, in: context)
    #expect(raw.toInt32(in: context) == 1)

    let decoded = global.getProperty(forKey: key, using: ZeroOneBoolConverter.self, in: context)
    #expect(decoded)
  }
}

@Test func converterOverrideForArgumentsRead() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let source = JSValue(number: 1, in: context)
    let rawArguments = [Optional(source.ref)]

    rawArguments.withUnsafeBufferPointer { buffer in
      let args = JSArguments(pointer: buffer.baseAddress!, count: 1)
      let decoded = args.unpack(at: 0, using: ZeroOneBoolConverter.self, in: context)
      #expect(decoded)
    }
  }
}

@Test func converterOverrideForArgumentsReadVariadic() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let boolSource = JSValue(number: 1, in: context)
    let numberSource = JSValue(number: 42.5, in: context)
    let rawArguments = [Optional(boolSource.ref), Optional(numberSource.ref)]

    rawArguments.withUnsafeBufferPointer { buffer in
      let args = JSArguments(pointer: buffer.baseAddress!, count: 2)
      let (decodedBool, decodedNumber): (Bool, Double) = args.unpack(
        using: ZeroOneBoolConverter.self,
        JSDefaultConverter<Double>.self,
        in: context
      )
      #expect(decodedBool)
      #expect(decodedNumber == 42.5)
    }
  }
}

@Test func strictTryDecodeRejectsMismatchedType() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let stringValue = JSValue(string: "x", in: context)
    do {
      let _: Double = try stringValue.tryDecode(in: context)
      Issue.record("Expected strict decode to fail")
    } catch {
      #expect(Bool(true))
    }
  }
}

@Test func strictTryUnpackRejectsMismatchedType() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let source = JSValue(string: "x", in: context)
    let rawArguments = [Optional(source.ref)]

    rawArguments.withUnsafeBufferPointer { buffer in
      let args = JSArguments(pointer: buffer.baseAddress!, count: 1)
      do {
        let _: (Double) = try args.tryUnpack(types: Double.self, in: context)
        Issue.record("Expected strict unpack to fail")
      } catch {
        #expect(Bool(true))
      }
    }
  }
}

@Test func strictTryEncodeCanFail() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let value = FailingEncodeValue()
    do {
      _ = try value.tryEncode(in: context)
      Issue.record("Expected strict encode to fail")
    } catch {
      #expect(Bool(true))
    }
  }
}

@Test func functionInitSupportsReturnAndErrorCoder() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let fn = JSValue(
      name: "coded",
      converters: JSDefaultConverter<Double>.self,
      returnCoder: ReturnPayloadEncoder.self,
      errorCoder: FailurePayloadEncoder.self,
      function: { (value: Double) throws(FailurePayload) -> ReturnPayload in
        if value < 0 {
          throw .bad
        }
        return ReturnPayload(value: value + 2)
      }
    )

    global.setProperty(fn, forKey: JSStringManaged("coded"), in: context)

    let success = context.evaluateScript("coded(40)")
    switch consume success {
    case .value(let value):
      #expect(value.toDouble(in: context) == 42)
    case .exception:
      Issue.record("Expected success path to use return coder")
    }

    let failure = context.evaluateScript("try { coded(-1) } catch (e) { e }")
    switch consume failure {
    case .value(let value):
      #expect(value.toString(in: context) == "bad")
    case .exception:
      Issue.record("Expected failure path to use error coder")
    }
  }
}

@Test func codableConverterRoundtripDirectObjectGraph() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let user = CodableUser(
      name: "alice",
      age: 30,
      active: true,
      tags: ["swift", "jsc"],
      address: CodableAddress(city: "shanghai", zip: 200000)
    )

    global.setProperty(
      user,
      forKey: JSStringManaged("user"),
      using: JSCodableValueConverter<CodableUser>.self,
      in: context
    )

    let decoded: CodableUser = global.getProperty(
      forKey: JSStringManaged("user"),
      using: JSCodableValueConverter<CodableUser>.self,
      in: context
    )

    #expect(decoded == user)
  }
}

@Test func macroDefaultSynthesisRoundtrip() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroDefaultUser(name: "alice", age: 42)
    global.setProperty(value, forKey: JSStringManaged("macroDefault"), in: context)

    let decoded: MacroDefaultUser = global.getProperty(
      forKey: JSStringManaged("macroDefault"),
      using: JSDefaultConverter<MacroDefaultUser>.self,
      in: context
    )

    #expect(decoded == value)
  }
}

@Test func macroTypeLevelDecoderEncoderOverride() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroDelegatedUser(score: 9)
    global.setProperty(value, forKey: JSStringManaged("macroDelegated"), in: context)

    let raw = global.getProperty(forKey: JSStringManaged("macroDelegated"), in: context)
    #expect(raw.toDouble(in: context) == 9)

    let decoded: MacroDelegatedUser = global.getProperty(
      forKey: JSStringManaged("macroDelegated"),
      using: JSDefaultConverter<MacroDelegatedUser>.self,
      in: context
    )
    #expect(decoded == value)
  }
}

@Test func macroFieldLevelOverrideUsesCustomConverter() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroFieldOverrideUser(name: "bob", active: true)
    global.setProperty(value, forKey: JSStringManaged("macroField"), in: context)

    let activeRaw = context.evaluateScript("macroField.active")
    switch consume activeRaw {
    case .value(let active):
      #expect(active.toInt32(in: context) == 1)
    case .exception:
      Issue.record("Expected macroField.active value")
    }

    _ = context.evaluateScript("macroField = { name: 'bob', active: 0 }")
    let decoded: MacroFieldOverrideUser = global.getProperty(
      forKey: JSStringManaged("macroField"),
      using: JSDefaultConverter<MacroFieldOverrideUser>.self,
      in: context
    )
    #expect(decoded == MacroFieldOverrideUser(name: "bob", active: false))
  }
}
