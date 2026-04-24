import SwiftJavaScriptTestSupport
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

  #expect(takeExceptionValue(JSResult<Int>.value(42)) == nil)
  #expect(takeExceptionValue(JSResult<Int>.exception(7)) == 7)
}

@Test func jsClassWrapsEngineSpecificClassHandle() {
  let handle = MockClassHandle(rawClass: MockClass(id: "Widget"))
  let jsClass = JSClass<MockEngine>(handleClass: handle)

  #expect(jsClass.classHandle() == handle)
  #expect(jsClass == JSClass<MockEngine>(handleClass: handle))
}

@Test func staticMemberProtocolsSupportGenericConsumption() {
  let context = mockInstantContext()
  let thisValue = mockUndefinedValue()
  let arguments = JSArguments<MockEngine>(
    count: 0,
    borrowedValueHandleAt: { _, _ in nil }
  )
  let staticValue = JSStaticValue<MockEngine>(
    name: "title",
    attributes: [.readOnly],
    getProperty: { context, _ in
      let value = context.makeString("title")
      return .value(JSValue(retaining: value))
    },
    setProperty: { context, _, _ in
      let value = context.makeString("set")
      return .value(JSValue(retaining: value))
    }
  )
  let staticFunction = JSStaticFunction<MockEngine>(
    name: "render",
    attributes: [.dontDelete],
    callAsFunction: { context, _, arguments in
      let value = context.makeNumber(arguments.count)
      return .value(JSValue(retaining: value))
    }
  )

  #expect(staticValue.definition.name == "title")
  #expect(staticValue.hostPropertyDescriptor().name == "title")
  #expect(staticFunction.definition.name == "render")
  #expect(staticFunction.hostFunctionDescriptor().name == "render")

  switch readStaticValue(staticValue, in: context, from: thisValue) {
  case .value(let value):
    #expect(value.borrowHandle().rawValue.kind == "string")
    #expect(value.borrowHandle().rawValue.payload == "runtime-token:title")
  case .exception:
    Issue.record("Expected static value read to succeed")
  }

  switch callStaticFunction(staticFunction, in: context, on: thisValue, with: arguments) {
  case .value(let value):
    #expect(value.borrowHandle().rawValue.kind == "number")
    #expect(value.borrowHandle().rawValue.payload == "runtime-token:0.0")
  case .exception:
    Issue.record("Expected static function call to succeed")
  }

  let failingStaticValue = JSStaticValue<MockEngine>(
    name: "broken",
    attributes: [.none],
    getProperty: { context, _ in
      let value = context.makeString("unused")
      return .value(JSValue(retaining: value))
    },
    setProperty: { context, _, _ in
      let error = context.makeString("error")
      return .exception(JSValue(retaining: error))
    }
  )

  if let exception = failingStaticValue.setPropertyException(
    in: context,
    on: thisValue,
    to: thisValue
  ) {
    #expect(exception.borrowHandle().rawValue.payload == "runtime-token:error")
  } else {
    Issue.record("Expected static value setter to produce an exception")
  }
}

@Test func jsClassAutoStorageComputesManagedParentAndFinalizeDepth() {
  let parentClass = mockClass("Parent")

  var parent = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  parent.className = "Parent"

  var child = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  child.className = "Child"
  child.parentClass = parentClass

  let backing = JSClassAutoNativeClassBacking<
    JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>,
    Int,
    Int
  >(definition: child) { jsClass in
    jsClass == parentClass ? parent : nil
  }

  let storage = JSClassAutoObjectStorage(
    definition: child,
    instance: DummyJSClassInstance()
  ) { jsClass in
    jsClass == parentClass ? parent : nil
  }

  #expect(backing.usesManagedParent)
  #expect(storage.finalizeDepth == 2)
}

@Test func jsClassAutoStorageTypedInstanceAccessIsSafe() {
  let instance = DummyJSClassInstance()
  let storage = JSClassAutoObjectStorage<
    JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>
  >(
    definition: JSEngineClassDefinition(),
    instance: instance,
    finalizeDepth: 1
  )

  #expect(storage.typedInstance(as: DummyJSClassInstance.self) === instance)
  #expect(storage.typedInstance(as: MockStringHandle.self) == nil)
}

@Test func jsClassDefinitionMetadataAndCallbackFlagsKeepShape() {
  let parentClass = mockClass("Parent")

  var definition = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  definition.version = 3
  definition.attributes = JSClassAttributes(rawValue: 0b101)
  definition.className = "Widget"
  definition.parentClass = parentClass
  definition.staticValues = [
    JSStaticValue(
      name: "title",
      attributes: [.readOnly],
      getProperty: { _, _ in .value(mockUndefinedValue()) },
      setProperty: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]
  definition.staticFunctions = [
    JSStaticFunction(
      name: "render",
      attributes: [.dontDelete],
      callAsFunction: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]
  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, _ in true }
  definition.getProperty = { _, _, _ in .value(mockUndefinedValue()) }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { _, _, _, _ in mockUndefinedValue() }
  definition.callAsConstructor = { _, _, _, _ in mockUndefinedValue() }
  definition.hasInstance = { _, _, _ in true }
  definition.convertToType = { _, _, _, _ in mockUndefinedValue() }

  let metadata = definition.classDefinition
  let callbacks = definition.callbackInstallationPlan

  #expect(metadata.version == 3)
  #expect(metadata.attributes == JSClassAttributes(rawValue: 0b101))
  #expect(metadata.className == "Widget")
  #expect(metadata.parentClass == parentClass)
  #expect(metadata.staticValues.map(\.name) == ["title"])
  #expect(metadata.staticValues.count == 1)
  #expect(metadata.staticValues[0].attributes == [.readOnly])
  #expect(metadata.staticFunctions.map(\.name) == ["render"])
  #expect(metadata.staticFunctions.count == 1)
  #expect(metadata.staticFunctions[0].attributes == [.dontDelete])
  #expect(callbacks.hasInitializer)
  #expect(callbacks.hasFinalizer)
  #expect(callbacks.hasDynamicPropertyGetter)
  #expect(callbacks.hasDynamicPropertySetter)
  #expect(callbacks.hasDynamicPropertyHas)
  #expect(callbacks.hasDynamicPropertyDelete)
  #expect(callbacks.hasPropertyEnumerator)
  #expect(callbacks.hasCallAsFunction)
  #expect(callbacks.hasConstructor)
  #expect(callbacks.hasHasInstance)
  #expect(callbacks.hasConvertToType)
}

@Test func jsClassDefinitionLookupTraversesParentChain() {
  let grandparentClass = mockClass("Grandparent")
  let parentClass = mockClass("Parent")

  var grandparent = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  grandparent.className = "Grandparent"
  grandparent.staticValues = [
    JSStaticValue(
      name: "grand",
      attributes: [.readOnly],
      getProperty: { _, _ in .value(mockUndefinedValue()) },
      setProperty: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]

  var parent = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  parent.className = "Parent"
  parent.parentClass = grandparentClass
  parent.staticFunctions = [
    JSStaticFunction(
      name: "parentFn",
      attributes: [.dontDelete],
      callAsFunction: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]

  var child = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  child.className = "Child"
  child.parentClass = parentClass

  let lookup = JSEngineClassDefinitionLookup<MockEngine, JSClass<MockEngine>, Never> { jsClass in
    switch jsClass {
    case parentClass:
      parent
    case grandparentClass:
      grandparent
    default:
      nil
    }
  }

  #expect(lookup.inheritanceDepth(of: child) == 3)
  #expect(lookup.exportedDefinitionCount(of: child) == 3)
  #expect(lookup.inheritedStaticValue(named: "grand", in: child)?.name == "grand")
  #expect(lookup.inheritedStaticFunction(named: "parentFn", in: child)?.name == "parentFn")
  #expect(lookup.inheritedStaticFunction(named: "missing", in: child) == nil)
}

@Test func engineClassDefinitionExportsCoreDefinition() {
  let parentClass = mockClass("Parent")

  var definition = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  definition.version = 7
  definition.attributes = JSClassAttributes(rawValue: 0b11)
  definition.className = "Widget"
  definition.parentClass = parentClass
  definition.staticValues = [
    JSStaticValue(
      name: "title",
      attributes: [.readOnly],
      getProperty: { _, _ in .value(mockUndefinedValue()) },
      setProperty: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]
  definition.staticFunctions = [
    JSStaticFunction(
      name: "render",
      attributes: [.dontDelete],
      callAsFunction: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]

  let classDefinition = definition.classDefinition

  #expect(classDefinition.version == 7)
  #expect(classDefinition.attributes == JSClassAttributes(rawValue: 0b11))
  #expect(classDefinition.className == "Widget")
  #expect(classDefinition.parentClass == parentClass)
  #expect(classDefinition.staticValues.map(\.name) == ["title"])
  #expect(classDefinition.staticFunctions.map(\.name) == ["render"])
}

@Test func engineClassDefinitionSeparatesDefinitionAndBehaviorStorage() {
  var definition = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  definition.definition.className = "Widget"
  definition.behavior.staticValues = [
    JSStaticValue(
      name: "title",
      attributes: [.readOnly],
      getProperty: { _, _ in .value(mockUndefinedValue()) },
      setProperty: { _, _, _ in .value(mockUndefinedValue()) }
    )
  ]

  #expect(definition.className == "Widget")
  #expect(definition.staticValues.map(\.name) == ["title"])
  #expect(definition.classDefinition.className == "Widget")
  #expect(definition.classDefinition.staticValues.map(\.name) == ["title"])
}

@Test func coreClassDefinitionLookupTraversesParentChain() {
  let grandparentClass = mockClass("Grandparent")
  let parentClass = mockClass("Parent")

  var grandparent = JSClassDefinitionMetadata<JSClass<MockEngine>>()
  grandparent.className = "Grandparent"
  grandparent.staticValues = [
    JSClassStaticValueDefinition(name: "grand", attributes: [.readOnly])
  ]

  var parent = JSClassDefinitionMetadata<JSClass<MockEngine>>()
  parent.className = "Parent"
  parent.parentClass = grandparentClass
  parent.staticFunctions = [
    JSClassStaticFunctionDefinition(name: "parentFn", attributes: [.dontDelete])
  ]

  var child = JSClassDefinitionMetadata<JSClass<MockEngine>>()
  child.className = "Child"
  child.parentClass = parentClass

  let lookup = JSClassDefinitionMetadataLookup<JSClass<MockEngine>> { jsClass in
    switch jsClass {
    case parentClass:
      parent
    case grandparentClass:
      grandparent
    default:
      nil
    }
  }

  #expect(lookup.inheritanceDepth(of: child) == 3)
  #expect(lookup.exportedDefinitionCount(of: child) == 3)
  #expect(lookup.inheritedStaticValue(named: "grand", in: child)?.name == "grand")
  #expect(lookup.inheritedStaticFunction(named: "parentFn", in: child)?.name == "parentFn")
  #expect(lookup.inheritedStaticFunction(named: "missing", in: child) == nil)
}

@Test func jsClassValueConverterAutoHelpersUseDefinitionAndLookup() {
  let parentClass = mockClass("Parent")

  var parent = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
  parent.className = "Parent"

  let lookup = JSEngineClassDefinitionLookup<MockEngine, JSClass<MockEngine>, Never> { jsClass in
    jsClass == parentClass ? parent : nil
  }

  let backing:
    JSClassAutoNativeClassBacking<
      JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>,
      Int,
      Int
    > =
      MockExportedJSClassInstance.autoNativeClassBacking(lookup: lookup)
  let storage = MockExportedJSClassInstance.autoObjectStorage(
    instance: MockExportedJSClassInstance(),
    lookup: lookup
  )

  #expect(backing.definition.className == "ExportedChild")
  #expect(backing.usesManagedParent)
  #expect(storage.definition.className == "ExportedChild")
  #expect(storage.finalizeDepth == 2)
}
