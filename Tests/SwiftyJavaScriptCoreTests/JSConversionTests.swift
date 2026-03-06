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
        let _: Double = try args.tryUnpack(
          at: 0, using: JSDefaultConverter<Double>.self, in: context)
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

@Test func jsValueCallSupportsThisAndArguments() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let functionResult = context.evaluateScript("(function(a, b) { return this.base + a + b })")

    switch consume functionResult {
    case .value(let function):
      let thisObject = JSValue(objectIn: context)
      thisObject.setProperty(10, forKey: JSStringManaged("base"), in: context)

      let callResult = function.call(this: thisObject, arguments: 1, 2, in: context)
      switch consume callResult {
      case .value(let value):
        #expect(value.toDouble(in: context) == 13)
      case .exception:
        Issue.record("Expected function.call to succeed")
      }
    case .exception:
      Issue.record("Expected callable function value")
    }
  }
}

@Test func jsValueConstructCreatesObject() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let constructorResult = context.evaluateScript(
      "(function Person(name) { this.name = name; this.kind = 'person' })"
    )

    switch consume constructorResult {
    case .value(let constructor):
      let constructResult = constructor.construct(arguments: "alice", in: context)
      switch consume constructResult {
      case .value(let instance):
        let isObject = instance.isObject
        let name = instance.getProperty(forKey: JSStringManaged("name"), in: context).toString(
          in: context)
        let kind = instance.getProperty(forKey: JSStringManaged("kind"), in: context).toString(
          in: context)
        #expect(isObject)
        #expect(name == "alice")
        #expect(kind == "person")
      case .exception:
        Issue.record("Expected constructor.construct to succeed")
      }
    case .exception:
      Issue.record("Expected constructor function value")
    }
  }
}

@Test func jsValueInvokeMethodUsesReceiverAndSurfacesErrors() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let objectResult = context.evaluateScript(
      "({ scale: 4, mul(value) { return this.scale * value } })")

    switch consume objectResult {
    case .value(let object):
      let invokeResult = object.invokeMethod(JSStringManaged("mul"), arguments: 5, in: context)
      switch consume invokeResult {
      case .value(let value):
        #expect(value.toDouble(in: context) == 20)
      case .exception:
        Issue.record("Expected method invocation to succeed")
      }

      let missingResult = object.invokeMethod(JSStringManaged("missing"), in: context)
      switch consume missingResult {
      case .value:
        Issue.record("Expected missing method invocation to raise exception")
      case .exception(let exception):
        let isObject = exception.isObject
        #expect(isObject)
      }
    case .exception:
      Issue.record("Expected object literal value")
    }
  }
}

@Test func jsValueObjectAndTypeHelpersWork() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let arrayResult = context.evaluateScript("[1, 2, 3]")
    let dateResult = context.evaluateScript("new Date(0)")
    let arrayConstructorResult = context.evaluateScript("Array")

    switch consume arrayResult {
    case .value(let array):
      switch consume dateResult {
      case .value(let date):
        switch consume arrayConstructorResult {
        case .value(let arrayConstructor):
          let arrayIsArray = array.isArray(in: context)
          let arrayIsDate = array.isDate(in: context)
          let dateIsDate = date.isDate(in: context)
          let isArrayInstance = array.isInstanceOf(arrayConstructor, in: context)
          #expect(arrayIsArray)
          #expect(!arrayIsDate)
          #expect(dateIsDate)
          #expect(isArrayInstance)

          let primitive = JSValue(number: 42, in: context)
          let objectResult = primitive.toObject(in: context)
          switch consume objectResult {
          case .value(let object):
            let isObject = object.isObject
            #expect(isObject)
          case .exception:
            Issue.record("Expected toObject to box primitive numbers")
          }

          #expect(primitive.toNumber(in: context) == 42)
        case .exception:
          Issue.record("Expected Array constructor value")
        }
      case .exception:
        Issue.record("Expected Date instance value")
      }
    case .exception:
      Issue.record("Expected array value")
    }
  }
}

@Test func jsValueDefinePropertyAppliesAttributes() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let object = JSValue(objectIn: context)
    let key = JSStringManaged("locked")

    let defineResult = object.defineProperty(7, forKey: key, with: [.readOnly], in: context)
    switch consume defineResult {
    case .value(let stored):
      #expect(stored.toInt32(in: context) == 7)
    case .exception:
      Issue.record("Expected defineProperty to succeed")
    }

    object.setProperty(9, forKey: key, in: context)
    let stored = object.getProperty(forKey: key, in: context)
    #expect(stored.toInt32(in: context) == 7)
  }
}
