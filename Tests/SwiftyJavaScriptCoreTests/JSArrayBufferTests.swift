import Testing

@testable import SwiftyJavaScriptCore

@Test func arrayBufferCreatesZeroedStorageAndSupportsMutation() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let buffer = JSArrayBuffer<JavaScriptCoreEngine>(byteLength: 4, in: context)
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

    global.setProperty(buffer, forKey: JSStringManaged("buffer"), in: context)
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

@Test func arrayBufferCanCopyBytesAndWrapExistingJSValue() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let copied = JSArrayBuffer<JavaScriptCoreEngine>(copying: [1, 2, 3, 4], in: context)
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
      if let wrapped = JSArrayBuffer<JavaScriptCoreEngine>(value: value, in: context) {
        #expect(wrapped.byteLength == 3)
      } else {
        Issue.record(
          "Expected JSValue<JavaScriptCoreEngine> to wrap as JSArrayBuffer")
      }
    case .exception:
      Issue.record("Expected JavaScript ArrayBuffer value")
    }
  }
}

@Test func typedArrayCreatesStorageAndExposesBytes() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let typedArray = JSTypedArray<JavaScriptCoreEngine>(type: .uint16Array, length: 4, in: context)

    typedArray.withUnsafeMutableBytes { rawBuffer in
      let words = rawBuffer.bindMemory(to: UInt16.self)
      words[0] = 5
      words[1] = 9
      words[3] = 12
    }

    global.setProperty(typedArray, forKey: JSStringManaged("typedArray"), in: context)
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

@Test func typedArrayCanWrapArrayBufferSliceAndExistingJSValue() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let buffer = JSArrayBuffer<JavaScriptCoreEngine>(
      copying: [10, 20, 30, 40, 50, 60], in: context)
    let typedArray = JSTypedArray<JavaScriptCoreEngine>(
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
      if let wrapped = JSTypedArray<JavaScriptCoreEngine>(value: value, in: context) {
        #expect(wrapped.kind == .uint8Array)
        #expect(wrapped.length == 5)
        #expect(wrapped.byteOffset == 0)
      } else {
        Issue.record(
          "Expected JSValue<JavaScriptCoreEngine> to wrap as JSTypedArray")
      }
    case .exception:
      Issue.record("Expected JavaScript TypedArray value")
    }
  }
}
