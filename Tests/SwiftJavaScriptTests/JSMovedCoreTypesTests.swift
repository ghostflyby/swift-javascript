import Testing

@testable import SwiftJavaScript

@Test func typedArrayKindBytesPerElementMatchesSpecification() {
  #expect(JSTypedArrayKind.int8Array.bytesPerElement == 1)
  #expect(JSTypedArrayKind.uint8Array.bytesPerElement == 1)
  #expect(JSTypedArrayKind.uint8ClampedArray.bytesPerElement == 1)
  #expect(JSTypedArrayKind.int16Array.bytesPerElement == 2)
  #expect(JSTypedArrayKind.uint16Array.bytesPerElement == 2)
  #expect(JSTypedArrayKind.int32Array.bytesPerElement == 4)
  #expect(JSTypedArrayKind.uint32Array.bytesPerElement == 4)
  #expect(JSTypedArrayKind.float32Array.bytesPerElement == 4)
  #expect(JSTypedArrayKind.float64Array.bytesPerElement == 8)
}

@Test func movedOptionSetsPreserveRawValueSemantics() {
  let property = JSPropertyAttributes(rawValue: 0b1011)
  let classAttr = JSClassAttributes(rawValue: 0b0010)

  #expect(property.rawValue == 0b1011)
  #expect(classAttr.rawValue == 0b0010)

  #expect(property.contains(JSPropertyAttributes(rawValue: 0b0010)))
  #expect(!property.contains(JSPropertyAttributes(rawValue: 0b0100)))
  #expect(classAttr.contains(JSClassAttributes(rawValue: 0b0010)))
}

@Test func jSTypeAndConversionErrorKeepSemanticPayloads() {
  let kinds: [JSType] = [
    .undefined, .null, .boolean, .number, .string, .symbol, .object, .bigInt,
  ]

  #expect(kinds.count == 8)
  #expect(kinds.contains(.bigInt))

  let error = JSValueConversionError.typeMismatch(expected: "number", actual: .string)
  switch error {
  case .typeMismatch(let expected, let actual):
    #expect(expected == "number")
    #expect(actual == .string)
  default:
    Issue.record("Expected typeMismatch error case")
  }
}
