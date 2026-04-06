import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

private func makeJavaScriptCoreArguments(
  _ pointer: UnsafePointer<JSValueRef?>,
  count: Int
) -> JSArguments<JavaScriptCoreEngine> {
  JSArguments<JavaScriptCoreEngine>(count: count) { index, contextHandle in
    guard index >= 0, index < count, let valueRef = pointer[index] else {
      return nil
    }
    return JavaScriptCoreValueHandle(ref: valueRef, contextRef: contextHandle.ref)
  }
}

@Test func builtinCodableRoundtrip() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let key = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("number")
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
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let key = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("flag")

    global.setProperty(true, forKey: key, using: ZeroOneBoolConverter.self, in: context)

    let raw = global.getProperty(forKey: key, in: context)
    #expect(raw.toInt32(in: context) == 1)

    let decoded = global.getProperty(forKey: key, using: ZeroOneBoolConverter.self, in: context)
    #expect(decoded)
  }
}

@Test func converterOverrideForArgumentsRead() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let source = JSValue(number: 1, in: context)
    let rawArguments = [Optional(source.ref)]

    rawArguments.withUnsafeBufferPointer { buffer in
      let args = makeJavaScriptCoreArguments(buffer.baseAddress!, count: 1)
      let decoded = args.unpack(at: 0, using: ZeroOneBoolConverter.self, in: context)
      #expect(decoded)
    }
  }
}

@Test func converterOverrideForArgumentsReadVariadic() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let boolSource = JSValue(number: 1, in: context)
    let numberSource = JSValue(number: 42.5, in: context)
    let rawArguments = [Optional(boolSource.ref), Optional(numberSource.ref)]

    rawArguments.withUnsafeBufferPointer { buffer in
      let args = makeJavaScriptCoreArguments(buffer.baseAddress!, count: 2)
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
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

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
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let source = JSValue(string: "x", in: context)
    let rawArguments = [Optional(source.ref)]

    rawArguments.withUnsafeBufferPointer { buffer in
      let args = makeJavaScriptCoreArguments(buffer.baseAddress!, count: 1)
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
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

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
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let fn: SwiftJavaScript.JSValue<JavaScriptCoreEngine> = JSValue(
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

    global.setProperty(
      fn, forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("coded"), in: context)

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
