import Testing

@testable import SwiftyJavaScriptCore

@Test func arrayBufferCreatesZeroedStorageAndSupportsMutation() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let buffer = JSArrayBuffer(byteLength: 4, in: context)
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
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let copied = JSArrayBuffer(copying: [1, 2, 3, 4], in: context)
    var copiedBytes: [UInt8] = []
    copied.withUnsafeBytes { rawBuffer in
      copiedBytes = Array(rawBuffer.bindMemory(to: UInt8.self))
    }

    let evaluated = context.evaluateScript("new ArrayBuffer(3)")

    #expect(copied.byteLength == 4)
    #expect(copiedBytes == [1, 2, 3, 4])

    switch consume evaluated {
    case .value(let value):
      let isArrayBuffer = value.isArrayBuffer
      #expect(isArrayBuffer)
      if let wrapped = JSArrayBuffer(value: value) {
        #expect(wrapped.byteLength == 3)
      } else {
        Issue.record("Expected JSValue to wrap as JSArrayBuffer")
      }
    case .exception:
      Issue.record("Expected JavaScript ArrayBuffer value")
    }
  }
}
