import Testing

@testable import SwiftyJavaScriptCore

@Test func classAttributesOptionSet() {
  let value: JSClassAttributes = [.noAutomaticPrototype]

  #expect(value.contains(.noAutomaticPrototype))
  #expect(JSClassAttributes.none.rawValue == 0)
}

@Test func staticValueAndFunctionStorage() {
  let staticValue = JSStaticValue(
    name: "value",
    attributes: .readOnly,
    getProperty: { context, _ in .value(JSValue(number: 1, in: context)) },
    setProperty: { context, _, _ in .value(JSValue(undefinedIn: context)) }
  )

  let staticFunction = JSStaticFunction(
    name: "fn",
    attributes: .dontEnum,
    callAsFunction: { context, _, _ in .value(JSValue(undefinedIn: context)) }
  )

  #expect(staticValue.name == "value")
  #expect(staticValue.attributes.contains(.readOnly))
  #expect(staticFunction.name == "fn")
  #expect(staticFunction.attributes.contains(.dontEnum))
}

@Test func classDefinitionDefaultsAndClassCreation() {
  var definition = JSClassDefinition()

  #expect(definition.version == 0)
  #expect(definition.attributes == .none)
  #expect(definition.className == nil)
  #expect(definition.parentClass == nil)
  #expect(definition.staticValues.isEmpty)
  #expect(definition.staticFunctions.isEmpty)

  definition.className = "MyClass"
  definition.attributes = .noAutomaticPrototype

  let cls = JSClass(defination: definition)
  let retained = JSClass(ref: cls.ref)

  _ = cls
  _ = retained
}

@Test func classDefinitionCallbacksAreSettable() {
  var definition = JSClassDefinition()

  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, name in name == "x" }
  definition.getProperty = { context, _, _ in .value(JSValue(undefinedIn: context)) }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in JSValue(undefinedIn: context) }
  definition.callAsConstructor = { context, _, _, _ in JSValue(undefinedIn: context) }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in JSValue(undefinedIn: context) }

  #expect(definition.initialize != nil)
  #expect(definition.finalize != nil)
  #expect(definition.hasProperty != nil)
  #expect(definition.getProperty != nil)
  #expect(definition.setProperty != nil)
  #expect(definition.deleteProperty != nil)
  #expect(definition.getPropertyNames != nil)
  #expect(definition.callAsFunction != nil)
  #expect(definition.callAsConstructor != nil)
  #expect(definition.hasInstance != nil)
  #expect(definition.convertToType != nil)
}

@Test func classDefinitionFullWiringSmoke() {
  var base = JSClassDefinition()
  base.className = "Base"
  let baseClass = JSClass(defination: base)

  var definition = JSClassDefinition()
  definition.version = 0
  definition.attributes = .noAutomaticPrototype
  definition.className = "FullWired"
  definition.parentClass = baseClass
  definition.staticValues = [
    JSStaticValue(
      name: "version",
      attributes: .readOnly,
      getProperty: { context, _ in .value(JSValue(number: 1, in: context)) },
      setProperty: { context, _, _ in .value(JSValue(undefinedIn: context)) }
    )
  ]
  definition.staticFunctions = [
    JSStaticFunction(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in .value(JSValue(string: "pong", in: context)) }
    )
  ]
  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, name in name == "version" }
  definition.getProperty = { context, _, _ in .value(JSValue(number: 42, in: context)) }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in JSValue(undefinedIn: context) }
  definition.callAsConstructor = { context, _, _, _ in JSValue(undefinedIn: context) }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in JSValue(undefinedIn: context) }

  let cls = JSClass(defination: definition)
  let retained = JSClass(ref: cls.ref)

  _ = retained
  #expect(definition.parentClass != nil)
  #expect(definition.staticValues.count == 1)
  #expect(definition.staticFunctions.count == 1)
}

@Test func classNameMutationStillBuildsClass() {
  var definition = JSClassDefinition()
  definition.className = "A"
  definition.className = "B"
  definition.className = "C"

  let cls = JSClass(defination: definition)
  let retained = JSClass(ref: cls.ref)

  _ = cls
  _ = retained
  #expect(definition.className == "C")
}
