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

@Test func functionInitSupportsVariadicConverters() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let fn = JSValue(
      name: "mix",
      converters: ZeroOneBoolConverter.self, JSDefaultConverter<Double>.self,
      function: { (flag: Bool, value: Double) in
        flag ? value + 1 : value - 1
      }
    )

    global.setProperty(fn, forKey: JSStringManaged("mix"), in: context)

    let result = context.evaluateScript("mix(1, 41)")
    switch consume result {
    case .value(let value):
      #expect(value.toDouble(in: context) == 42)
    case .exception:
      Issue.record("Expected converted function call to succeed")
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
