import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

@Test func staticValueAndFunctionStorage() {
  let staticValue = SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>(
    name: "value",
    attributes: .readOnly,
    getProperty: { context, _ in
      .value(JSValue(number: 1, in: context))
    },
    setProperty: { context, _, _ in
      .value(JSValue(undefinedIn: context))
    }
  )

  let staticFunction = SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>(
    name: "fn",
    attributes: .dontEnum,
    callAsFunction: { context, _, _ in
      .value(JSValue(undefinedIn: context))
    }
  )

  #expect(staticValue.name == "value")
  #expect(staticValue.attributes.contains(.readOnly))
  #expect(staticFunction.name == "fn")
  #expect(staticFunction.attributes.contains(.dontEnum))
}

@Test func classDefinitionDefaultsAndClassCreation() {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()

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
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()

  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, name in name == "x" }
  definition.getProperty = { context, _, _ in
    .value(JSValue(undefinedIn: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }

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
  var base = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()
  base.className = "Base"
  let baseClass = JSClass(defination: base)

  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()
  definition.version = 0
  definition.attributes = .noAutomaticPrototype
  definition.className = "FullWired"
  definition.parentClass = baseClass
  definition.staticValues = [
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>(
      name: "version",
      attributes: .readOnly,
      getProperty: { context, _ in
        .value(JSValue(number: 1, in: context))
      },
      setProperty: { context, _, _ in
        .value(JSValue(undefinedIn: context))
      }
    )
  ]
  definition.staticFunctions = [
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in
        .value(JSValue(string: "pong", in: context))
      }
    )
  ]
  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, name in name == "version" }
  definition.getProperty = { context, _, _ in
    .value(JSValue(number: 42, in: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }

  let cls = JSClass(defination: definition)
  let retained = JSClass(ref: cls.ref)

  _ = retained
  #expect(definition.parentClass != nil)
  #expect(definition.staticValues.count == 1)
  #expect(definition.staticFunctions.count == 1)
}

@Test func classNameMutationStillBuildsClass() {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()
  definition.className = "A"
  definition.className = "B"
  definition.className = "C"

  let cls = JSClass(defination: definition)
  let retained = JSClass(ref: cls.ref)

  _ = cls
  _ = retained
  #expect(definition.className == "C")
}

@Test func classDefinitionProjectsHostTypeDescriptor() {
  var parentDefinition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()
  parentDefinition.className = "BaseType"
  let parentClass = JSClass(defination: parentDefinition)

  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >()
  definition.className = "ProjectedType"
  definition.parentClass = parentClass
  definition.staticValues = [
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>(
      name: "version",
      attributes: [.readOnly, .dontDelete],
      getProperty: { context, _ in
        .value(JSValue(number: 1, in: context))
      },
      setProperty: { context, _, _ in
        .value(JSValue(undefinedIn: context))
      }
    )
  ]
  definition.staticFunctions = [
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in
        .value(JSValue(string: "pong", in: context))
      }
    )
  ]
  definition.initialize = { _, _ in }
  definition.hasProperty = { _, _, name in name == "version" }
  definition.getProperty = { context, _, _ in
    .value(JSValue(number: 1, in: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSValue(objectIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSValue(string: "converted", in: context)
  }
  definition.finalize = { _ in }

  let descriptor = definition.hostTypeDescriptor(storagePolicy: .swiftRetainedObject)

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
