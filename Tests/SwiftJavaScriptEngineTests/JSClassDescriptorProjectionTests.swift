import Foundation
import JavaScriptCore
import Testing

@testable import SwiftJavaScript
import SwiftyJavaScriptCore

private func makeTestClass() -> JSCClass {
  var definition = kJSClassDefinitionEmpty
  return JSCClass(ref: JSClassCreate(&definition)!)
}

@Test func classDefinitionProjectsHostTypeDescriptor() {
  let parentClass = makeTestClass()

  var definition = JSEngineClassDefinition<JSCEngine, JSCClass, JSPropertyNameAccumulatorRef>()
  definition.className = "ProjectedType"
  definition.parentClass = parentClass
  definition.staticValues = [
    JSStaticValue<JSCEngine>(
      name: "version",
      attributes: [.readOnly, .dontDelete],
      getProperty: { _, _ in fatalError("descriptor projection does not invoke callbacks") },
      setProperty: { _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
    )
  ]
  definition.staticFunctions = [
    JSStaticFunction<JSCEngine>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
    )
  ]
  definition.initialize = { _, _ in }
  definition.hasProperty = { _, _, name in name == "version" }
  definition.getProperty = { _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { _, _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.callAsConstructor = { _, _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { _, _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.finalize = { _ in }

  let descriptor = definition.hostTypeDescriptor(
    storagePolicy: .swiftRetainedObject,
    parentName: "BaseType"
  )

  #expect(descriptor.name == "ProjectedType")
  #expect(descriptor.parent == "BaseType")
  #expect(descriptor.storagePolicy == .swiftRetainedObject)
  #expect(descriptor.initializerBinding == "ProjectedType.initialize")
  #expect(descriptor.constructor?.binding == "ProjectedType.constructor")
  #expect(descriptor.finalizerBinding == "ProjectedType.finalize")
  #expect(descriptor.dynamicPropertyGetterBinding == "ProjectedType.dynamicProperty.get")
  #expect(descriptor.dynamicPropertySetterBinding == "ProjectedType.dynamicProperty.set")
  #expect(descriptor.dynamicPropertyHasBinding == "ProjectedType.dynamicProperty.has")
  #expect(descriptor.dynamicPropertyDeleteBinding == "ProjectedType.dynamicProperty.delete")
  #expect(descriptor.propertyEnumeratorBinding == "ProjectedType.dynamicProperty.enumerate")
  #expect(descriptor.callAsFunctionBinding == "ProjectedType.call")
  #expect(descriptor.hasInstanceBinding == "ProjectedType.hasInstance")
  #expect(descriptor.convertToTypeBinding == "ProjectedType.convertToType")
  #expect(descriptor.methods.count == 1)
  #expect(descriptor.methods[0].name == "ping")
  #expect(descriptor.methods[0].binding == "ProjectedType.method.ping")
  #expect(descriptor.methods[0].attributes.contains(.dontEnum))
  #expect(descriptor.staticMethods.isEmpty)
  #expect(descriptor.properties.count == 1)
  #expect(descriptor.properties[0].name == "version")
  #expect(descriptor.properties[0].getterBinding == "ProjectedType.property.get.version")
  #expect(descriptor.properties[0].setterBinding == "ProjectedType.property.set.version")
  #expect(descriptor.properties[0].attributes.contains(.readOnly))
  #expect(descriptor.properties[0].attributes.contains(.dontDelete))
}

@Test func classDefinitionProjectsHostDescriptorBindings() {
  var definition = JSEngineClassDefinition<JSCEngine, JSCClass, JSPropertyNameAccumulatorRef>()
  definition.className = "BackendProjected"
  definition.staticValues = [
    JSStaticValue<JSCEngine>(
      name: "version",
      attributes: .readOnly,
      getProperty: { _, _ in fatalError("descriptor projection does not invoke callbacks") },
      setProperty: { _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
    )
  ]
  definition.staticFunctions = [
    JSStaticFunction<JSCEngine>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
    )
  ]
  definition.getProperty = { _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.setProperty = { _, _, _, _ in nil }
  definition.hasProperty = { _, _, _ in true }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { _, _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.callAsConstructor = { _, _, _, _ in fatalError("descriptor projection does not invoke callbacks") }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { _, _, _, _ in fatalError("descriptor projection does not invoke callbacks") }

  let descriptor = definition.hostTypeDescriptor(parentName: nil)

  #expect(descriptor.name == "BackendProjected")
  #expect(!descriptor.properties.isEmpty)
  #expect(!descriptor.methods.isEmpty)
  #expect(descriptor.dynamicPropertyGetterBinding != nil)
  #expect(descriptor.dynamicPropertySetterBinding != nil)
  #expect(descriptor.dynamicPropertyHasBinding != nil)
  #expect(descriptor.dynamicPropertyDeleteBinding != nil)
  #expect(descriptor.propertyEnumeratorBinding != nil)
  #expect(descriptor.callAsFunctionBinding != nil)
  #expect(descriptor.constructor?.binding != nil)
  #expect(descriptor.hasInstanceBinding != nil)
  #expect(descriptor.convertToTypeBinding != nil)
}

@Test func classNameMutationStillBuildsClass() {
  var definition = JSEngineClassDefinition<JSCEngine, JSCClass, JSPropertyNameAccumulatorRef>()
  definition.className = "A"
  definition.className = "B"
  definition.className = "C"

  #expect(definition.className == "C")
}
