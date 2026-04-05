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

@Test func hostMemberAttributesOptionSetCombinesAndPreservesFlags() {
  let attributes: JSHostMemberAttributes = [.readOnly, .dontDelete]

  #expect(attributes.contains(.readOnly))
  #expect(!attributes.contains(.dontEnum))
  #expect(attributes.contains(.dontDelete))
  #expect(
    attributes.rawValue
      == (JSHostMemberAttributes.readOnly.rawValue | JSHostMemberAttributes.dontDelete.rawValue))
}

@Test func hostDescriptorsUseDocumentedDefaults() {
  let function = JSHostFunctionDescriptor(name: "f")
  let property = JSHostPropertyDescriptor(name: "p")
  let constant = JSHostConstantDescriptor(name: "k", value: 1)
  let type = JSHostTypeDescriptor(name: "T")
  let module = JSHostModuleDescriptor(name: "M")

  #expect(function.attributes == .none)
  #expect(function.binding == nil)

  #expect(property.attributes == .none)
  #expect(property.getterBinding == nil)
  #expect(property.setterBinding == nil)

  #expect(constant.attributes == .none)

  #expect(type.storagePolicy == .swiftRetainedObject)
  #expect(type.methods.isEmpty)
  #expect(type.staticMethods.isEmpty)
  #expect(type.properties.isEmpty)

  #expect(module.functions.isEmpty)
  #expect(module.constants.isEmpty)
  #expect(module.types.isEmpty)
}

@Test func hostTypeDescriptorRetainsOptionalBindings() {
  let descriptor = JSHostTypeDescriptor(
    name: "Widget",
    constructor: JSHostConstructorDescriptor(binding: "widget_ctor"),
    dynamicPropertyHasBinding: "widget_dynamic_has",
    dynamicPropertyDeleteBinding: "widget_dynamic_delete",
    hasInstanceBinding: "widget_has_instance",
    convertToTypeBinding: "widget_convert_to_type"
  )

  #expect(descriptor.constructor?.binding == "widget_ctor")
  #expect(descriptor.hasInstanceBinding == "widget_has_instance")
  #expect(descriptor.convertToTypeBinding == "widget_convert_to_type")
  #expect(descriptor.dynamicPropertyHasBinding == "widget_dynamic_has")
  #expect(descriptor.dynamicPropertyDeleteBinding == "widget_dynamic_delete")
}

@Test func hostTypeDescriptorDefaultsOptionalBindingsToNil() {
  let descriptor = JSHostTypeDescriptor(name: "Defaults")

  #expect(descriptor.constructor == nil)
  #expect(descriptor.hasInstanceBinding == nil)
  #expect(descriptor.convertToTypeBinding == nil)
  #expect(descriptor.dynamicPropertyHasBinding == nil)
  #expect(descriptor.dynamicPropertyDeleteBinding == nil)
}

@Test func jsResultPayloadKeepsValueAndExceptionCases() {
  let ok = JSResult<Int>.value(42)
  let failure = JSResult<Int>.exception(7)

  switch ok {
  case .value(let value):
    #expect(value == 42)
  case .exception:
    Issue.record("Expected value case")
  }

  switch failure {
  case .value:
    Issue.record("Expected exception case")
  case .exception(let value):
    #expect(value == 7)
  }
}

@Test func utilityBoxesStoreAndExposePayload() {
  let boxed = Box(123)
  let sendableBox = SendableBoxUnsafe("payload")

  #expect(boxed.value == 123)
  #expect(sendableBox.value == "payload")
}
