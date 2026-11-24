import SwiftyJavaScriptCore
import SwiftyQuickJS
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
    switch engine {
    case .javaScriptCore:
      await FunctionInitSupportsReturnAndErrorCoderJSC.run()
    case .quickJS:
      await FunctionInitSupportsReturnAndErrorCoderQJS.run()
    }
  }
}

private enum SharedZeroOneBoolConverter: JSValueConverter {
  typealias SwiftType = Bool

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Bool {
    _ = context
    return value.toNumber() != 0
  }

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: Bool,
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(value ? 1 : 0))
  }
}

private struct SharedFailingEncodeValue: JSValueEncodable {
  func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeUndefined())
  }

  func tryEncodeSurface<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    _ = context
    throw .nonFiniteNumber(target: "SharedFailingEncodeValue")
  }
}

private struct SharedReturnPayload {
  let value: Double
}

private enum SharedReturnPayloadEncoder: JSValueEncoder {
  typealias SwiftType = SharedReturnPayload

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: SharedReturnPayload,
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeNumber(value.value))
  }
}

private enum SharedFailurePayload: Error {
  case bad
}

private enum SharedFailurePayloadEncoder: JSValueEncoder {
  typealias SwiftType = SharedFailurePayload

  static func encode<C: JSValueScope & ~Copyable>(
    _ value: SharedFailurePayload,
    in context: borrowing C
  ) -> C.Value {
    switch value {
    case .bad:
      return context.persist(context.makeString("bad"))
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
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let key: StaticString = "number"
      scope.setGlobalProperty(42.5, forKey: key)

      let raw = scope.getGlobalProperty(forKey: key)
      let decoded = try? Double(value: raw, in: scope)
      #expect(decoded == 42.5)

      let scriptValue = scope.evaluateScript("'abc'")
      switch consume scriptValue {
      case .value(let value):
        #expect(value.toString() == "abc")
      case .exception:
        Issue.record("Expected string result")
      }
    }
  }
}

private enum CodableConverterRoundtripDirectObjectGraph: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let user = SharedCodableUser(
        name: "alice",
        age: 30,
        active: true,
        tags: ["swift", "js"],
        address: SharedCodableAddress(city: "shanghai", zip: 200000)
      )
      let key: StaticString = "user"

      scope.setGlobalProperty(
        user,
        forKey: key,
        using: JSCodableValueConverter<SharedCodableUser>.self
      )

      let encoded = scope.getGlobalProperty(forKey: key)
      let decoded = try? JSCodableValueConverter<SharedCodableUser>.tryDecode(
        encoded, in: scope)

      #expect(decoded == user)
    }
  }
}

private enum ConverterOverrideForPropertyReadWrite: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let key: StaticString = "flag"

      scope.setGlobalProperty(
        true, forKey: key, using: SharedZeroOneBoolConverter.self)

      let raw = scope.getGlobalProperty(forKey: key)
      #expect(raw.toNumber() == 1)

      let decoded = try? SharedZeroOneBoolConverter.tryDecode(raw, in: scope)
      #expect(decoded == true)
    }
  }
}

// MARK: - Test argument view
//
// The surface `JSArguments` protocol is the argument face; this stand-in
// exposes borrowed handles as the engine's value views, so the shared
// variadic decode helpers can be exercised without an engine call frame.

private struct SurfaceTestArguments<C: JSContext>: JSArguments, ~Copyable {
  typealias Context = C
  typealias Value = C.Value
  typealias InstantContext = C.InstantContext

  let handles: [C.ValueHandle]

  var count: Int { handles.count }

  func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing C.InstantContext,
    _ body: (borrowing C.Value) -> R
  ) -> R {
    precondition(index >= 0 && index < count, "Index out of bounds")
    return body(context.anchorBorrowedHandle(handles[index]))
  }
}

private enum ConverterOverrideForArgumentsRead: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let source = scope.makeNumber(1)
      let args = SurfaceTestArguments<C>(
        handles: [source.borrowHandle()]
      )
      let decoded: Bool = args.unpack(
        using: SharedZeroOneBoolConverter.self, in: scope)
      #expect(decoded)
    }
  }
}

private enum ConverterOverrideForArgumentsReadVariadic: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let boolSource = scope.makeNumber(1)
      let numberSource = scope.makeNumber(42.5)
      let args = SurfaceTestArguments<C>(
        handles: [boolSource.borrowHandle(), numberSource.borrowHandle()]
      )
      let (decodedBool, decodedNumber): (Bool, Double) = args.unpack(
        using: SharedZeroOneBoolConverter.self,
        JSDefaultConverter<Double>.self,
        in: scope
      )
      #expect(decodedBool)
      #expect(decodedNumber == 42.5)
    }
  }
}

private enum StrictTryDecodeRejectsMismatchedType: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let stringValue = scope.persist(scope.makeString("x"))
      do {
        let _: Double = try JSDefaultConverter<Double>.tryDecode(
          stringValue, in: scope)
        Issue.record("Expected strict decode to fail")
      } catch {
        #expect(Bool(true))
      }
    }
  }
}

private enum StrictTryUnpackRejectsMismatchedType: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let source = scope.makeString("x")
      let args = SurfaceTestArguments<C>(
        handles: [source.borrowHandle()]
      )
      do {
        let _: Double = try args.tryUnpack(
          using: JSDefaultConverter<Double>.self, in: scope)
        Issue.record("Expected strict unpack to fail")
      } catch {
        #expect(Bool(true))
      }
    }
  }
}

private enum StrictTryEncodeCanFail: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let value = SharedFailingEncodeValue()
      do {
        _ = try value.tryEncodeSurface(in: scope)
        Issue.record("Expected strict encode to fail")
      } catch {
        #expect(Bool(true))
      }
    }
  }
}

/// The function-callback initializer lives on the concrete engine value type
/// and takes an isolated engine context, so this contract runs once per
/// engine instead of generically.
private enum FunctionInitSupportsReturnAndErrorCoderJSC {
  static func run() async {
    let context = JSCContext()
    await context.installCodedFunctionAndCheck()
  }
}

private enum FunctionInitSupportsReturnAndErrorCoderQJS {
  static func run() async {
    let context = QJSContext()
    await context.installCodedFunctionAndCheck()
  }
}

extension JSCContext {
  fileprivate func installCodedFunctionAndCheck() {
    let fn = JSCValue(
      in: self,
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
    setGlobalProperty(fn, forKey: "coded", with: .none)
    assertFunctionInitCoderBehavior()
  }

  private func assertFunctionInitCoderBehavior() {
    let success = evaluateScript("coded(40)")
    switch consume success {
    case .value(let value):
      #expect(value.toNumber() == 42)
    case .exception:
      Issue.record("Expected success path to use return coder")
    }

    let failure = evaluateScript("try { coded(-1) } catch (e) { e }")
    switch consume failure {
    case .value(let value):
      #expect(value.toString() == "bad")
    case .exception:
      Issue.record("Expected failure path to use error coder")
    }
  }
}

extension QJSContext {
  fileprivate func installCodedFunctionAndCheck() {
    let fn = QJSValue(
      in: self,
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
    setGlobalProperty(fn, forKey: "coded", with: .none)
    assertFunctionInitCoderBehavior()
  }

  private func assertFunctionInitCoderBehavior() {
    let success = evaluateScript("coded(40)")
    switch consume success {
    case .value(let value):
      #expect(value.toNumber() == 42)
    case .exception:
      Issue.record("Expected success path to use return coder")
    }

    let failure = evaluateScript("try { coded(-1) } catch (e) { e }")
    switch consume failure {
    case .value(let value):
      #expect(value.toString() == "bad")
    case .exception:
      Issue.record("Expected failure path to use error coder")
    }
  }
}
