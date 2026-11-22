import Testing

@testable import SwiftJavaScript

@Suite
struct EngineValueConversionTests {
  @Test(arguments: ScriptEngine.allCases)
  func builtinCodableRoundtrip(_ engine: ScriptEngine) async {
    await engine.run(BuiltinCodableRoundtrip.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func codableConverterRoundtripDirectObjectGraph(_ engine: ScriptEngine) async {
    await engine.run(CodableConverterRoundtripDirectObjectGraph.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func converterOverrideForPropertyReadWrite(_ engine: ScriptEngine) async {
    await engine.run(ConverterOverrideForPropertyReadWrite.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func converterOverrideForArgumentsRead(_ engine: ScriptEngine) async {
    await engine.run(ConverterOverrideForArgumentsRead.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func converterOverrideForArgumentsReadVariadic(_ engine: ScriptEngine) async {
    await engine.run(ConverterOverrideForArgumentsReadVariadic.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func strictTryDecodeRejectsMismatchedType(_ engine: ScriptEngine) async {
    await engine.run(StrictTryDecodeRejectsMismatchedType.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func strictTryUnpackRejectsMismatchedType(_ engine: ScriptEngine) async {
    await engine.run(StrictTryUnpackRejectsMismatchedType.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func strictTryEncodeCanFail(_ engine: ScriptEngine) async {
    await engine.run(StrictTryEncodeCanFail.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func functionInitSupportsReturnAndErrorCoder(_ engine: ScriptEngine) async {
    await engine.run(FunctionInitSupportsReturnAndErrorCoder.self)
  }
}

private enum SharedZeroOneBoolConverter: JSValueConverter {
  typealias SwiftType = Bool

  static func decode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    value.toDouble(in: context) != 0
  }

  static func encode<E: JSValueConversionEngine>(
    _ value: Bool,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    JSValue(number: value ? 1 : 0, in: context)
  }
}

private struct SharedFailingEncodeValue: JSValueEncodable {
  func toJSValue<E: JSValueConversionEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<
    E
  > {
    JSValue(undefinedIn: context)
  }

  func tryEncode<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    _ = context
    throw .nonFiniteNumber(target: "SharedFailingEncodeValue")
  }
}

private struct SharedReturnPayload {
  let value: Double
}

private enum SharedReturnPayloadEncoder: JSValueEncoder {
  typealias SwiftType = SharedReturnPayload

  static func encode<E: JSValueConversionEngine>(
    _ value: SharedReturnPayload,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    JSValue(number: value.value, in: context)
  }
}

private enum SharedFailurePayload: Error {
  case bad
}

private enum SharedFailurePayloadEncoder: JSValueEncoder {
  typealias SwiftType = SharedFailurePayload

  static func encode<E: JSValueConversionEngine>(
    _ value: SharedFailurePayload,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    switch value {
    case .bad:
      return JSValue(string: "bad", in: context)
    }
  }
}

private struct SharedCodableAddress: Codable, Equatable {
  let city: String
  let zip: Int
}

private struct SharedCodableUser: Codable, Equatable {
  let name: String
  let age: Int
  let active: Bool
  let tags: [String]
  let address: SharedCodableAddress
}

private enum BuiltinCodableRoundtrip: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let key: StaticString = "number"
      context.withGlobalObject { global in
        global.setProperty(42.5, forKey: key, in: context)
      }

      let decoded = context.withGlobalObject { global in
        global.getProperty(forKey: key, using: JSDefaultConverter<Double>.self, in: context)
      }
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
}

private enum CodableConverterRoundtripDirectObjectGraph: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let user = SharedCodableUser(
        name: "alice",
        age: 30,
        active: true,
        tags: ["swift", "js"],
        address: SharedCodableAddress(city: "shanghai", zip: 200000)
      )
      let key: StaticString = "user"

      context.withGlobalObject { global in
        global.setProperty(
          user,
          forKey: key,
          using: JSCodableValueConverter<SharedCodableUser>.self,
          in: context
        )
      }

      let decoded: SharedCodableUser = context.withGlobalObject { global in
        global.getProperty(
          forKey: key,
          using: JSCodableValueConverter<SharedCodableUser>.self,
          in: context
        )
      }

      #expect(decoded == user)
    }
  }
}

private enum ConverterOverrideForPropertyReadWrite: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let key: StaticString = "flag"

      context.withGlobalObject { global in
        global.setProperty(true, forKey: key, using: SharedZeroOneBoolConverter.self, in: context)
      }

      let raw = context.withGlobalObject { global in
        global.getProperty(forKey: key, in: context)
      }
      #expect(raw.toInt32(in: context) == 1)

      let decoded = context.withGlobalObject { global in
        global.getProperty(forKey: key, using: SharedZeroOneBoolConverter.self, in: context)
      }
      #expect(decoded)
    }
  }
}

private enum ConverterOverrideForArgumentsRead: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let source = JSValue(number: 1, in: context)
      let sourceHandle = source.borrowHandle()
      let args = JSArguments<E>(
        count: 1,
        borrowedValueHandleAt: { index, _ in index == 0 ? sourceHandle : nil }
      )
      let decoded = args.unpack(at: 0, using: SharedZeroOneBoolConverter.self, in: context)
      #expect(decoded)
    }
  }
}

private enum ConverterOverrideForArgumentsReadVariadic: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let boolSource = JSValue(number: 1, in: context)
      let numberSource = JSValue(number: 42.5, in: context)
      let boolHandle = boolSource.borrowHandle()
      let numberHandle = numberSource.borrowHandle()
      let args = JSArguments<E>(
        count: 2,
        borrowedValueHandleAt: { index, _ in
          switch index {
          case 0:
            return boolHandle
          case 1:
            return numberHandle
          default:
            return nil
          }
        }
      )
      let (decodedBool, decodedNumber): (Bool, Double) = args.unpack(
        using: SharedZeroOneBoolConverter.self,
        JSDefaultConverter<Double>.self,
        in: context
      )
      #expect(decodedBool)
      #expect(decodedNumber == 42.5)
    }
  }
}

private enum StrictTryDecodeRejectsMismatchedType: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let stringValue = JSValue(string: "x", in: context)
      do {
        let _: Double = try JSDefaultConverter<Double>.tryDecode(stringValue, in: context)
        Issue.record("Expected strict decode to fail")
      } catch {
        #expect(Bool(true))
      }
    }
  }
}

private enum StrictTryUnpackRejectsMismatchedType: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let source = JSValue(string: "x", in: context)
      let sourceHandle = source.borrowHandle()
      let args = JSArguments<E>(
        count: 1,
        borrowedValueHandleAt: { index, _ in index == 0 ? sourceHandle : nil }
      )
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

private enum StrictTryEncodeCanFail: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let value = SharedFailingEncodeValue()
      do {
        _ = try value.tryEncode(in: context)
        Issue.record("Expected strict encode to fail")
      } catch {
        #expect(Bool(true))
      }
    }
  }
}

private enum FunctionInitSupportsReturnAndErrorCoder: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withIsolatedGlobalObject { context, global in
      let fn: JSValue<E> = JSValue(
        in: context,
        name: "coded",
        converters: JSDefaultConverter<Double>.self,
        returnCoder: SharedReturnPayloadEncoder.self,
        errorCoder: SharedFailurePayloadEncoder.self,
        function: { (value: Double) throws(SharedFailurePayload) -> SharedReturnPayload in
          if value < 0 {
            throw .bad
          }
          return SharedReturnPayload(value: value + 2)
        }
      )

      global.setProperty(fn, forKey: ("coded"), in: context)

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
}
