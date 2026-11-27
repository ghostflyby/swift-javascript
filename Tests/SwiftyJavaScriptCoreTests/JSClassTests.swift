import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

@JSClassAutoConvertible
final class JSCMacroNode {
  var name: String = ""
}

enum JSCMacroMethodError: Error {
  case bad
}

@JSClassAutoConvertible
final class JSCMacroMethodNode {
  var base: Double = 1

  @JSClassFunction
  func sum(_ lhs: Double, _ rhs: Double) -> Double {
    base + lhs + rhs
  }

  @JSClassFunction("describe")
  func describe(_ prefix: String) -> String {
    "\(prefix):\(base)"
  }

  @JSClassFunction("fail")
  func fail() throws(JSCMacroMethodError) -> String {
    throw .bad
  }

  @JSClassFunction("flag")
  @JSClassFunctionArguments(ZeroOneBoolConverter.self)
  func flag(_ enabled: Bool) -> Bool {
    enabled
  }

  @JSClassFunction("payload")
  @JSClassFunctionReturn(ReturnPayloadEncoder.self)
  func payload() -> ReturnPayload {
    ReturnPayload(value: base * 2)
  }

  @JSClassFunction("failEncoded")
  @JSClassFunctionError(FailurePayloadEncoder.self)
  func failEncoded() throws(FailurePayload) -> String {
    throw .bad
  }
}

private final class JSCExportedNode: JSClassValueConvertible, @unchecked Sendable {
  typealias Context = JSCContext
  typealias ParentClass = JSCClassParentDescriptor
  typealias PropertyNameAccumulator = JSPropertyNameAccumulatorRef
  typealias ClassDefinition = JSCAutoClassDefinition

  var name: String

  init(name: String) {
    self.name = name
  }

  static var jsClassDefinition: JSCAutoClassDefinition {
    var definition = JSCAutoClassDefinition()
    definition.className = "JSCExportedNode"
    definition.hasProperty = { _, _, property in property == "name" }
    definition.getProperty = { context, this, property in
      guard let instance = try? Self.tryDecode(this, in: context) else {
        return .exception(JSCValue(string: "failed to decode JSCExportedNode", in: context))
      }
      switch property {
      case "name":
        return .value(JSCValue(string: instance.name, in: context))
      default:
        return .value(JSCValue(undefinedIn: context))
      }
    }
    definition.setProperty = { context, this, property, value in
      guard let instance = try? Self.tryDecode(this, in: context) else {
        return JSCValue(string: "failed to decode JSCExportedNode", in: context)
      }
      if property == "name" {
        instance.name = value.toString()
      }
      return nil
    }
    return definition
  }
}

@Test func staticValueAndFunctionStorage() {
  let staticValue = SwiftJavaScript.JSStaticValue<JSCContext>(
    name: "value",
    attributes: .readOnly,
    getProperty: { context, _ in
      .value(JSCValue(number: 1, in: context))
    },
    setProperty: { context, _, _ in
      .value(JSCValue(undefinedIn: context))
    }
  )

  let staticFunction = SwiftJavaScript.JSStaticFunction<JSCContext>(
    name: "fn",
    attributes: .dontEnum,
    callAsFunction: { context, _, _ in
      .value(JSCValue(undefinedIn: context))
    }
  )

  #expect(staticValue.name == "value")
  #expect(staticValue.attributes.contains(.readOnly))
  #expect(staticFunction.name == "fn")
  #expect(staticFunction.attributes.contains(.dontEnum))
}

@Test func classDefinitionDefaultsAndClassCreation() {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()

  #expect(definition.version == 0)
  #expect(definition.attributes == .none)
  #expect(definition.className == nil)
  #expect(definition.parentClass == nil)
  #expect(definition.staticValues.isEmpty)
  #expect(definition.staticFunctions.isEmpty)

  definition.className = "MyClass"
  definition.attributes = .noAutomaticPrototype

  let cls = JSCClass(defination: definition)
  let retained = JSCClass(ref: cls.ref)

  _ = cls
  _ = retained
}

@Test func classDefinitionCallbacksAreSettable() {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()

  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, name in name == "x" }
  definition.getProperty = { context, _, _ in
    .value(JSCValue(undefinedIn: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSCValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSCValue(undefinedIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSCValue(undefinedIn: context)
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
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()
  base.className = "Base"
  let baseClass = JSCClass(defination: base)

  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()
  definition.version = 0
  definition.attributes = .noAutomaticPrototype
  definition.className = "FullWired"
  definition.parentClass = baseClass
  definition.staticValues = [
    SwiftJavaScript.JSStaticValue<JSCContext>(
      name: "version",
      attributes: .readOnly,
      getProperty: { context, _ in
        .value(JSCValue(number: 1, in: context))
      },
      setProperty: { context, _, _ in
        .value(JSCValue(undefinedIn: context))
      }
    )
  ]
  definition.staticFunctions = [
    SwiftJavaScript.JSStaticFunction<JSCContext>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in
        .value(JSCValue(string: "pong", in: context))
      }
    )
  ]
  definition.initialize = { _, _ in }
  definition.finalize = { _ in }
  definition.hasProperty = { _, _, name in name == "version" }
  definition.getProperty = { context, _, _ in
    .value(JSCValue(number: 42, in: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSCValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSCValue(undefinedIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSCValue(undefinedIn: context)
  }

  let cls = JSCClass(defination: definition)
  let retained = JSCClass(ref: cls.ref)

  _ = retained
  #expect(definition.parentClass != nil)
  #expect(definition.staticValues.count == 1)
  #expect(definition.staticFunctions.count == 1)
}

@Test func classNameMutationStillBuildsClass() {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()
  definition.className = "A"
  definition.className = "B"
  definition.className = "C"

  let cls = JSCClass(defination: definition)
  let retained = JSCClass(ref: cls.ref)

  _ = cls
  _ = retained
  #expect(definition.className == "C")
}

@Test func classDefinitionProjectsHostTypeDescriptor() {
  var parentDefinition = SwiftJavaScript.JSEngineClassDefinition<
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()
  parentDefinition.className = "BaseType"
  let parentClass = JSCClass(defination: parentDefinition)

  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JSCContext, JSCClass, JSPropertyNameAccumulatorRef
  >()
  definition.className = "ProjectedType"
  definition.parentClass = parentClass
  definition.staticValues = [
    SwiftJavaScript.JSStaticValue<JSCContext>(
      name: "version",
      attributes: [.readOnly, .dontDelete],
      getProperty: { context, _ in
        .value(JSCValue(number: 1, in: context))
      },
      setProperty: { context, _, _ in
        .value(JSCValue(undefinedIn: context))
      }
    )
  ]
  definition.staticFunctions = [
    SwiftJavaScript.JSStaticFunction<JSCContext>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in
        .value(JSCValue(string: "pong", in: context))
      }
    )
  ]
  definition.initialize = { _, _ in }
  definition.hasProperty = { _, _, name in name == "version" }
  definition.getProperty = { context, _, _ in
    .value(JSCValue(number: 1, in: context))
  }
  definition.setProperty = { _, _, _, _ in nil }
  definition.deleteProperty = { _, _, _ in true }
  definition.getPropertyNames = { _, _, _ in }
  definition.callAsFunction = { context, _, _, _ in
    JSCValue(undefinedIn: context)
  }
  definition.callAsConstructor = { context, _, _, _ in
    JSCValue(objectIn: context)
  }
  definition.hasInstance = { _, _, _ in false }
  definition.convertToType = { context, _, _, _ in
    JSCValue(string: "converted", in: context)
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

@Test func autoClassDefinitionRoundTripsThroughJavaScript() throws {
  let runtime = JSContextGroupCreate()!
  guard let contextHandle = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
    Issue.record("JSCEngine could not create a context handle")
    return
  }
  let context = JSCInstantContext(contextRef: contextHandle)

  let instance = JSCExportedNode(name: "leaf")
  let encoded = try JSCExportedNode.tryEncode(instance, in: context)
  context.setGlobalProperty(encoded, forKey: "node")

  switch context.evaluateScript("node.name") {
  case .value(let value):
    #expect(value.toString() == "leaf")
  case .exception:
    Issue.record("Expected auto class-backed property to be readable")
  }

  _ = context.evaluateScript("node.name = 'branch'")
  #expect(instance.name == "branch")

  let decoded = try JSCExportedNode.tryDecode(encoded, in: context)
  #expect(decoded === instance)
}

@Test func macroGeneratedClassDefinitionUsesSurfaceCallbacks() throws {
  let runtime = JSContextGroupCreate()!
  guard let contextHandle = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
    Issue.record("JSCEngine could not create a context handle")
    return
  }
  let context = JSCInstantContext(contextRef: contextHandle)

  let node = JSCMacroNode()
  node.name = "macro"
  let encoded = try JSCMacroNode.tryEncode(node, in: context)
  context.setGlobalProperty(encoded, forKey: "node")

  switch context.evaluateScript("node.name") {
  case .value(let value):
    #expect(value.toString() == "macro")
  case .exception:
    Issue.record("Expected macro-generated class property to be readable")
  }

  _ = context.evaluateScript("node.name = 'updated'")
  #expect(node.name == "updated")
}

@Test func macroGeneratedClassMethodsUseSurfaceCallbacks() throws {
  let runtime = JSContextGroupCreate()!
  guard let contextHandle = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
    Issue.record("JSCEngine could not create a context handle")
    return
  }
  let context = JSCInstantContext(contextRef: contextHandle)

  let node = JSCMacroMethodNode()
  let encoded = try JSCMacroMethodNode.tryEncode(node, in: context)
  context.setGlobalProperty(encoded, forKey: "methodNode")

  switch context.evaluateScript("methodNode.sum(2, 3)") {
  case .value(let value):
    #expect(value.toNumber() == 6)
  case .exception:
    Issue.record("Expected macro-generated class method to decode arguments and encode its return")
  }

  switch context.evaluateScript("methodNode.describe('base')") {
  case .value(let value):
    #expect(value.toString() == "base:1.0")
  case .exception:
    Issue.record("Expected macro-generated class method to honor its custom JS name")
  }

  switch context.evaluateScript("methodNode.fail()") {
  case .value:
    Issue.record("Expected macro-generated throwing class method to surface an exception")
  case .exception(let value):
    #expect(value.toString() == "bad")
  }

  switch context.evaluateScript("methodNode.flag(2)") {
  case .value(let value):
    let isEnabled = value.toBoolean()
    #expect(isEnabled)
  case .exception:
    Issue.record("Expected macro-generated argument decoder override to be used")
  }

  switch context.evaluateScript("methodNode.payload()") {
  case .value(let value):
    #expect(value.toNumber() == 2)
  case .exception:
    Issue.record("Expected macro-generated return encoder to be used")
  }

  switch context.evaluateScript("methodNode.failEncoded()") {
  case .value:
    Issue.record("Expected macro-generated error encoder to surface an exception")
  case .exception(let value):
    #expect(value.toString() == "bad")
  }
}
