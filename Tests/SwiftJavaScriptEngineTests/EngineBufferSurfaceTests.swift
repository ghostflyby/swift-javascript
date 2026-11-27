import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

@testable import SwiftJavaScript

// MARK: - Surface buffers across both engines (S10)
//
// The same generic assertions run on JavaScriptCore and QuickJS: construction
// (zero-filled, copying, empty, wrapping an existing value), shape
// (`kind`/`length`/`byteLength`/`byteOffset`/`buffer`), byte access, and the
// non-zero `byteOffset` overlay that core applies to the backing pointer.

@Suite
struct EngineBufferSurfaceTests {
  @Test(arguments: ScriptEngine.allCases)
  func arrayBufferSurfaceRoundTrip(_ engine: ScriptEngine) async {
    await engine.run(ArrayBufferSurfaceRoundTrip.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func typedArraySurfaceExposesShape(_ engine: ScriptEngine) async {
    await engine.run(TypedArraySurfaceExposesShape.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func typedArraySurfaceSlicesNonZeroOffset(_ engine: ScriptEngine) async {
    await engine.run(TypedArraySurfaceSlicesNonZeroOffset.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func buffersWrapOnlyMatchingValues(_ engine: ScriptEngine) async {
    await engine.run(BuffersWrapOnlyMatchingValues.self)
  }
}

private enum ArrayBufferSurfaceRoundTrip: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let buffer = C.ArrayBuffer(byteLength: 8, in: scope)
      let zeroed = buffer.bytes
      let isBuffer = buffer.withValue { value in
        value.isArrayBuffer(in: scope)
      }
      let bufferByteLength = buffer.byteLength

      buffer.withUnsafeMutableBytes { rawBuffer in
        let bytes = rawBuffer.bindMemory(to: UInt8.self)
        bytes[0] = 7
        bytes[7] = 9
      }
      let mutated = buffer.bytes

      buffer.withValue { value in
        scope.setGlobalProperty(value, forKey: "surfaceBuffer", with: .none)
      }
      let observableSum = surfaceNumber(
        C.InstantContext.self,
        in: scope,
        "new Uint8Array(surfaceBuffer)[0] + new Uint8Array(surfaceBuffer)[7]")

      // Copying initializers, including the empty-buffer path.
      let copied = C.ArrayBuffer(copying: [1, 2, 3, 4], in: scope)
      let copiedBytes = copied.bytes
      var rawCopiedByteLength = 0
      var rawCopiedBytes: [UInt8] = []
      let rawSource: [UInt8] = [9, 8, 7]
      rawSource.withUnsafeBytes { bytes in
        let rawCopied = C.ArrayBuffer(copying: bytes, in: scope)
        rawCopiedByteLength = rawCopied.byteLength
        rawCopiedBytes = rawCopied.bytes
      }
      let empty = C.ArrayBuffer(byteLength: 0, in: scope)
      let emptyByteLength = empty.byteLength
      let emptyBytes = empty.bytes

      #expect(bufferByteLength == 8)
      #expect(zeroed == [0, 0, 0, 0, 0, 0, 0, 0])
      #expect(isBuffer)
      #expect(mutated == [7, 0, 0, 0, 0, 0, 0, 9])
      #expect(observableSum == 16)

      #expect(copied.byteLength == 4)
      #expect(copiedBytes == [1, 2, 3, 4])

      #expect(rawCopiedByteLength == 3)
      #expect(rawCopiedBytes == [9, 8, 7])

      #expect(emptyByteLength == 0)
      #expect(emptyBytes.isEmpty)
    }
  }
}

private enum TypedArraySurfaceExposesShape: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let typedArray = C.TypedArray(kind: .uint16Array, length: 4, in: scope)
      let kind = typedArray.kind
      let length = typedArray.length
      let byteLength = typedArray.byteLength
      let byteOffset = typedArray.byteOffset
      let bufferByteLength = typedArray.buffer.byteLength
      let zeroedBytes = typedArray.bytes

      typedArray.withUnsafeMutableBytes { rawBuffer in
        let words = rawBuffer.bindMemory(to: UInt16.self)
        words[0] = 5
        words[1] = 9
        words[3] = 12
      }
      let mutatedByteCount = typedArray.bytes.count

      typedArray.withValue { value in
        scope.setGlobalProperty(value, forKey: "surfaceTypedArray", with: .none)
      }
      let observableSum = surfaceNumber(
        C.InstantContext.self,
        in: scope,
        """
        surfaceTypedArray.length + surfaceTypedArray.byteOffset + \
        surfaceTypedArray.BYTES_PER_ELEMENT + surfaceTypedArray[0] + \
        surfaceTypedArray[1] + surfaceTypedArray[3]
        """
      )

      #expect(kind == .uint16Array)
      #expect(length == 4)
      #expect(byteLength == 8)
      #expect(byteOffset == 0)
      #expect(bufferByteLength == 8)
      #expect(zeroedBytes == [0, 0, 0, 0, 0, 0, 0, 0])
      #expect(mutatedByteCount == 8)
      #expect(observableSum == 32)
    }
  }
}

private enum TypedArraySurfaceSlicesNonZeroOffset: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let buffer = C.ArrayBuffer(copying: [10, 20, 30, 40, 50, 60], in: scope)

      let slice = C.TypedArray(
        kind: .uint8Array,
        buffer: buffer,
        byteOffset: 2,
        length: 3,
        in: scope
      )
      let sliceKind = slice.kind
      let sliceLength = slice.length
      let sliceByteLength = slice.byteLength
      let sliceByteOffset = slice.byteOffset
      let sliceBufferByteLength = slice.buffer.byteLength
      let sliceBytes = slice.bytes

      // Open-ended slice: core derives the element count from the remaining
      // buffer bytes.
      let tail = C.TypedArray(
        kind: .uint8Array,
        buffer: buffer,
        byteOffset: 2,
        length: nil,
        in: scope
      )
      let tailLength = tail.length
      let tailBytes = tail.bytes

      // The whole-buffer convenience initializer.
      let whole = C.TypedArray(kind: .uint16Array, buffer: buffer, in: scope)
      let wholeKind = whole.kind
      let wholeLength = whole.length
      let wholeByteOffset = whole.byteOffset
      let wholeByteCount = whole.bytes.count

      // A write through the slice lands at the slice's offset in the buffer.
      slice.withUnsafeMutableBytes { rawBuffer in
        rawBuffer.bindMemory(to: UInt8.self)[0] = 99
      }
      let bufferAfterWrite = buffer.bytes

      #expect(sliceKind == .uint8Array)
      #expect(sliceLength == 3)
      #expect(sliceByteLength == 3)
      #expect(sliceByteOffset == 2)
      #expect(sliceBufferByteLength == 6)
      #expect(sliceBytes == [30, 40, 50])

      #expect(tailLength == 4)
      #expect(tailBytes == [30, 40, 50, 60])

      #expect(wholeKind == .uint16Array)
      #expect(wholeLength == 3)
      #expect(wholeByteOffset == 0)
      #expect(wholeByteCount == 6)

      #expect(bufferAfterWrite == [10, 20, 99, 40, 50, 60])
    }
  }
}

private enum BuffersWrapOnlyMatchingValues: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { scope in
      let wrappedBufferByteLength: Int?
      if let wrapped = surfaceBuffer(C.self, "new ArrayBuffer(3)", in: scope) {
        wrappedBufferByteLength = wrapped.byteLength
      } else {
        wrappedBufferByteLength = nil
        Issue.record("evaluated ArrayBuffer did not wrap")
      }

      let wrappedKind: JSTypedArrayKind?
      let wrappedLength: Int?
      let wrappedByteOffset: Int?
      if let wrapped = surfaceTypedArray(
        C.self,
        "new Uint8Array(new ArrayBuffer(5))",
        in: scope
      ) {
        wrappedKind = wrapped.kind
        wrappedLength = wrapped.length
        wrappedByteOffset = wrapped.byteOffset
      } else {
        wrappedKind = nil
        wrappedLength = nil
        wrappedByteOffset = nil
        Issue.record("evaluated TypedArray did not wrap")
      }

      let offsetArrayByteOffset: Int?
      let offsetArrayLength: Int?
      if let offsetArray = surfaceTypedArray(
        C.self,
        "new Uint16Array(new ArrayBuffer(8), 2)",
        in: scope
      ) {
        offsetArrayByteOffset = offsetArray.byteOffset
        offsetArrayLength = offsetArray.length
      } else {
        offsetArrayByteOffset = nil
        offsetArrayLength = nil
        Issue.record("offset TypedArray did not wrap")
      }

      let plainNumber = surfaceValue(C.InstantContext.self, in: scope, "21")
      let rejectedBuffer = surfaceBuffer(C.self, "21", in: scope) == nil
      let rejectedArray = surfaceTypedArray(C.self, "21", in: scope) == nil
      let numberIsPresent = plainNumber != nil

      #expect(numberIsPresent)
      #expect(wrappedBufferByteLength == 3)
      #expect(wrappedKind == .uint8Array)
      #expect(wrappedLength == 5)
      #expect(wrappedByteOffset == 0)
      #expect(offsetArrayByteOffset == 2)
      #expect(offsetArrayLength == 3)
      #expect(rejectedBuffer)
      #expect(rejectedArray)
    }
  }
}

// MARK: - Shared engine-agnostic helpers
//
// The `_ contextType:` parameter is the repository's workaround for the
// compiler's NoUsage diagnostic on `borrowing` parameters whose type is an
// associated type of the generic parameter (same shape as the S9 helpers).

/// Evaluate `source` and return its value view, or `nil` for an exception.
private func surfaceValue<C: JSInstantContext & ~Copyable>(
  _ contextType: C.Type,
  in scope: borrowing C,
  _ source: String
) -> C.Value? {
  _ = contextType
  let result = scope.evaluateScript(source)
  switch consume result {
  case .value(let value):
    return value
  case .exception:
    return nil
  }
}

/// Evaluate `source` and reduce it to a number, or `nil` for an exception.
private func surfaceNumber<C: JSInstantContext & ~Copyable>(
  _ contextType: C.Type,
  in scope: borrowing C,
  _ source: String
) -> Double? {
  guard let value = surfaceValue(contextType, in: scope, source) else {
    return nil
  }
  return value.toNumber()
}

/// Evaluate `source` and wrap the result as an ArrayBuffer.
private func surfaceBuffer<C: JSContext>(
  _ contextType: C.Type,
  _ source: String,
  in scope: borrowing C.InstantContext
) -> C.ArrayBuffer? {
  _ = contextType
  guard let value = surfaceValue(C.InstantContext.self, in: scope, source) else {
    return nil
  }
  return C.ArrayBuffer(value: value, in: scope)
}

/// Evaluate `source` and wrap the result as a TypedArray.
private func surfaceTypedArray<C: JSContext>(
  _ contextType: C.Type,
  _ source: String,
  in scope: borrowing C.InstantContext
) -> C.TypedArray? {
  _ = contextType
  guard let value = surfaceValue(C.InstantContext.self, in: scope, source) else {
    return nil
  }
  return C.TypedArray(value: value, in: scope)
}
