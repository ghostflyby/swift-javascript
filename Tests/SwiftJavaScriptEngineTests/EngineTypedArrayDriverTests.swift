import Testing

@testable import SwiftJavaScript

@Suite
struct EngineTypedArrayDriverTests {
  @Test(arguments: ScriptEngine.allCases)
  func arrayBufferAndTypedArrayBehavior(_ engine: ScriptEngine) async {
    await engine.run(ArrayBufferAndTypedArrayBehavior.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func arrayBufferCreatesZeroedStorageAndSupportsMutation(_ engine: ScriptEngine) async {
    await engine.run(ArrayBufferCreatesZeroedStorageAndSupportsMutation.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func arrayBufferCanCopyBytesAndWrapExistingJSValue(_ engine: ScriptEngine) async {
    await engine.run(ArrayBufferCanCopyBytesAndWrapExistingJSValue.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func typedArrayCreatesStorageAndExposesBytes(_ engine: ScriptEngine) async {
    await engine.run(TypedArrayCreatesStorageAndExposesBytes.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func typedArrayCanWrapArrayBufferSliceAndExistingJSValue(_ engine: ScriptEngine) async {
    await engine.run(TypedArrayCanWrapArrayBufferSliceAndExistingJSValue.self)
  }
}

private enum ArrayBufferAndTypedArrayBehavior: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let buffer = JSArrayBuffer<E>(copying: [10, 20, 30, 40, 50, 60], in: context)
      let invalidTypedArrayHandle = buffer.withJSValue { bufferValue in
        E.makeTypedArrayHandle(
          in: context.driverContextHandle,
          kind: .uint16Array,
          arrayBuffer: bufferValue.borrowHandle(),
          byteOffset: 1,
          length: 1
        )
      }
      #expect(invalidTypedArrayHandle == nil)

      let postFailureEvaluation = context.evaluateScript("21 + 21")
      switch consume postFailureEvaluation {
      case .value(let value):
        let result = value.toInt32(in: context)
        #expect(result == 42)
      case .exception:
        Issue.record("Expected typed array construction failure to leave evaluation usable")
      }

      let typedArrayHandle = buffer.withJSValue { bufferValue in
        E.makeTypedArrayHandle(
          in: context.driverContextHandle,
          kind: .uint8Array,
          arrayBuffer: bufferValue.borrowHandle(),
          byteOffset: 2,
          length: 3
        )
      }
      guard let typedArrayHandle else {
        Issue.record("Expected engine to create typed array with ArrayBuffer slice")
        return
      }

      let typedArrayValue = JSValue<E>(
        handleValue: typedArrayHandle, in: context.driverContextHandle)
      guard let typedArray = JSTypedArray<E>(value: typedArrayValue, in: context) else {
        Issue.record("Expected created value to wrap as JSTypedArray")
        return
      }

      var copiedBytes: [UInt8] = []
      typedArray.withUnsafeBytes { rawBuffer in
        copiedBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }

      let bufferByteLength = buffer.byteLength
      let typedArrayKind = typedArray.kind
      let typedArrayLength = typedArray.length
      let typedArrayByteOffset = typedArray.byteOffset
      let typedArrayByteLength = typedArray.byteLength
      let typedArrayBufferByteLength = typedArray.buffer.byteLength

      #expect(bufferByteLength == 6)
      #expect(typedArrayKind == .uint8Array)
      #expect(typedArrayLength == 3)
      #expect(typedArrayByteOffset == 2)
      #expect(typedArrayByteLength == 3)
      #expect(typedArrayBufferByteLength == 6)
      #expect(copiedBytes == [30, 40, 50])

      let wholeBufferArray = JSTypedArray<E>(
        type: .uint8Array,
        buffer: buffer,
        in: context
      )
      var wholeBufferBytes: [UInt8] = []
      wholeBufferArray.withUnsafeBytes { rawBuffer in
        wholeBufferBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }
      let wholeBufferArrayKind = wholeBufferArray.kind
      let wholeBufferArrayLength = wholeBufferArray.length
      let wholeBufferArrayByteOffset = wholeBufferArray.byteOffset
      let wholeBufferArrayByteLength = wholeBufferArray.byteLength

      #expect(wholeBufferArrayKind == .uint8Array)
      #expect(wholeBufferArrayLength == 6)
      #expect(wholeBufferArrayByteOffset == 0)
      #expect(wholeBufferArrayByteLength == 6)
      #expect(wholeBufferBytes == [10, 20, 30, 40, 50, 60])

      guard
        let lengthConstructedHandle = E.makeTypedArrayHandle(
          in: context.driverContextHandle,
          kind: .uint16Array,
          length: 4
        )
      else {
        Issue.record("Expected engine to create typed array by length")
        return
      }

      let lengthConstructedValue = JSValue<E>(
        handleValue: lengthConstructedHandle, in: context.driverContextHandle)
      guard let lengthConstructed = JSTypedArray<E>(value: lengthConstructedValue, in: context)
      else {
        Issue.record("Expected length-created value to wrap as JSTypedArray")
        return
      }

      let lengthConstructedKind = lengthConstructed.kind
      let lengthConstructedLength = lengthConstructed.length
      let lengthConstructedByteLength = lengthConstructed.byteLength
      #expect(lengthConstructedKind == .uint16Array)
      #expect(lengthConstructedLength == 4)
      #expect(lengthConstructedByteLength == 8)
    }
  }
}

private enum ArrayBufferCreatesZeroedStorageAndSupportsMutation: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let buffer = JSArrayBuffer<E>(byteLength: 4, in: context)
      let length = buffer.byteLength

      var initialBytes: [UInt8] = []
      buffer.withUnsafeBytes { rawBuffer in
        initialBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }

      buffer.withUnsafeMutableBytes { rawBuffer in
        let bytes = rawBuffer.bindMemory(to: UInt8.self)
        bytes[0] = 7
        bytes[3] = 9
      }

      context.withGlobalObject { global in
        global.setProperty(buffer, forKey: "buffer", in: context)
      }
      let result = context.evaluateScript("new Uint8Array(buffer)[0] + new Uint8Array(buffer)[3]")

      #expect(length == 4)
      #expect(initialBytes == [0, 0, 0, 0])

      switch consume result {
      case .value(let value):
        #expect(value.toInt32(in: context) == 16)
      case .exception:
        Issue.record("Expected ArrayBuffer bytes to be visible from JavaScript")
      }
    }
  }
}

private enum ArrayBufferCanCopyBytesAndWrapExistingJSValue: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let copied = JSArrayBuffer<E>(copying: [1, 2, 3, 4], in: context)
      var copiedBytes: [UInt8] = []
      copied.withUnsafeBytes { rawBuffer in
        copiedBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }

      let evaluated = context.evaluateScript("new ArrayBuffer(3)")

      #expect(copied.byteLength == 4)
      #expect(copiedBytes == [1, 2, 3, 4])

      switch consume evaluated {
      case .value(let value):
        let isArrayBuffer = value.isArrayBuffer(in: context)
        #expect(isArrayBuffer)
        if let wrapped = JSArrayBuffer<E>(value: value, in: context) {
          #expect(wrapped.byteLength == 3)
        } else {
          Issue.record("Expected JSValue to wrap as JSArrayBuffer")
        }
      case .exception:
        Issue.record("Expected JavaScript ArrayBuffer value")
      }
    }
  }
}

private enum TypedArrayCreatesStorageAndExposesBytes: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let typedArray = JSTypedArray<E>(type: .uint16Array, length: 4, in: context)

      typedArray.withUnsafeMutableBytes { rawBuffer in
        let words = rawBuffer.bindMemory(to: UInt16.self)
        words[0] = 5
        words[1] = 9
        words[3] = 12
      }

      context.withGlobalObject { global in
        global.setProperty(typedArray, forKey: "typedArray", in: context)
      }
      let result = context.evaluateScript(
        "typedArray.length + typedArray.byteOffset + typedArray.BYTES_PER_ELEMENT + typedArray[0] + typedArray[1] + typedArray[3]"
      )

      #expect(typedArray.kind == .uint16Array)
      #expect(typedArray.length == 4)
      #expect(typedArray.byteOffset == 0)
      #expect(typedArray.byteLength == 8)
      #expect(typedArray.buffer.byteLength == 8)

      switch consume result {
      case .value(let value):
        #expect(value.toInt32(in: context) == 32)
      case .exception:
        Issue.record("Expected TypedArray bytes to be visible from JavaScript")
      }
    }
  }
}

private enum TypedArrayCanWrapArrayBufferSliceAndExistingJSValue: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let buffer = JSArrayBuffer<E>(
        copying: [10, 20, 30, 40, 50, 60], in: context)
      let typedArray = JSTypedArray<E>(
        type: .uint8Array,
        buffer: buffer,
        byteOffset: 2,
        length: 3,
        in: context
      )

      var copiedBytes: [UInt8] = []
      typedArray.withUnsafeBytes { rawBuffer in
        copiedBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
      }

      let evaluated = context.evaluateScript("new Uint8Array(new ArrayBuffer(5))")

      #expect(typedArray.kind == .uint8Array)
      #expect(typedArray.byteOffset == 2)
      #expect(typedArray.length == 3)
      #expect(typedArray.byteLength == 3)
      #expect(typedArray.buffer.byteLength == 6)
      #expect(copiedBytes == [30, 40, 50])

      switch consume evaluated {
      case .value(let value):
        let isTypedArray = value.isTypedArray(in: context)
        #expect(isTypedArray)
        if let wrapped = JSTypedArray<E>(value: value, in: context) {
          #expect(wrapped.kind == .uint8Array)
          #expect(wrapped.length == 5)
          #expect(wrapped.byteOffset == 0)
        } else {
          Issue.record("Expected JSValue to wrap as JSTypedArray")
        }
      case .exception:
        Issue.record("Expected JavaScript TypedArray value")
      }
    }
  }
}
