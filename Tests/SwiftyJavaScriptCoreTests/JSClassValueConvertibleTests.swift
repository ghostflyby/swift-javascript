import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

@JSClassAutoConvertible
class ExportedBaseNode {
  var base: Double

  init(base: Double) {
    self.base = base
  }
}

@JSClassAutoConvertible
class ExportedChildNode: ExportedBaseNode {
  var child: String

  init(base: Double, child: String) {
    self.child = child
    super.init(base: base)
  }
}

@JSClassAutoConvertible
class ExportedLeafNode: ExportedChildNode {
  var enabled: Bool

  init(base: Double, child: String, enabled: Bool) {
    self.enabled = enabled
    super.init(base: base, child: child)
  }
}

enum UppercaseStringDecoder: JSValueDecoder {
  typealias SwiftType = String

  static func decode<E: JSEngine>(
    _ value: borrowing SwiftJavaScript.JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> String {
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    return decode(
      SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
        handleValue: unsafeBitCast(
          value.valueHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
      ),
      in: JSInstantContext<JavaScriptCoreEngine>(
        handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
      )
    )
  }

  static func decode(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  )
    -> String
  {
    value.toString(in: context).uppercased()
  }
}

@JSClassAutoConvertible
class ExportedFunctionNode {
  var name: String
  var count: Double

  init(name: String, count: Double) {
    self.name = name
    self.count = count
  }

  @JSClassFunction
  func sum(_ lhs: Double, _ rhs: Double) -> Double {
    lhs + rhs + count
  }

  @JSClassFunction("loudLabel")
  @JSClassFunctionArguments(UppercaseStringDecoder.self, ZeroOneBoolConverter.self)
  func renderLabel(_ prefix: String, enabled: Bool) -> String {
    "\(prefix):\(name):\(enabled ? "on" : "off")"
  }

  @JSClassFunctionReturn(ReturnPayloadEncoder.self)
  @JSClassFunction
  func payload() -> ReturnPayload {
    ReturnPayload(value: count * 2)
  }

  @JSClassFunctionError(FailurePayloadEncoder.self)
  @JSClassFunction
  func fail() throws(FailurePayload) -> String {
    throw .bad
  }
}

@Test func jsClassAutoConvertibleRoundTripsReferenceIdentity() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let instance = ExportedLeafNode(base: 1, child: "leaf", enabled: true)
    global.setProperty(
      instance, forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("node"), in: context)

    let decoded: ExportedLeafNode = global.getProperty(
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("node"),
      using: JSClassValueConverter<ExportedLeafNode>.self,
      in: context
    )

    #expect(decoded === instance)
  }
}

@Test func jsClassAutoConvertibleReflectsInheritedStoredProperties() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let instance = ExportedLeafNode(base: 2, child: "branch", enabled: true)
    global.setProperty(
      instance, forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("node"), in: context)

    let readResult = context.evaluateScript(
      "String(node.base) + ':' + node.child + ':' + String(node.enabled)")
    switch consume readResult {
    case .value(let value):
      #expect(value.toString(in: context) == "2:branch:true")
    case .exception:
      Issue.record("Expected JSClass-backed object properties to be readable from JavaScript")
    }

    let writeResult = context.evaluateScript(
      "node.base = 9; node.child = 'updated'; node.enabled = false; node.base")
    switch consume writeResult {
    case .value(let value):
      #expect(value.toDouble(in: context) == 9)
    case .exception:
      Issue.record("Expected JSClass-backed object properties to be writable from JavaScript")
    }

    #expect(instance.base == 9)
    #expect(instance.child == "updated")
    #expect(instance.enabled == false)
  }
}

@Test func jsClassAutoConvertibleBuildsJSClassAndPrototypeInheritanceChain() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  let hasParentClass =
    ExportedChildNode.jsClassDefinition.parentClass?.ref == ExportedBaseNode.jsClass.ref
  let hasLeafParentClass =
    ExportedLeafNode.jsClassDefinition.parentClass?.ref == ExportedChildNode.jsClass.ref
  #expect(hasParentClass)
  #expect(hasLeafParentClass)

  await context.withIsolatedGlobalObject { context, global in
    let base = ExportedBaseNode(base: 1)
    let child = ExportedChildNode(base: 2, child: "two")
    global.setProperty(
      base, forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("baseNode"), in: context)
    global.setProperty(
      child, forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("childNode"), in: context
    )

    let prototypeResult = context.evaluateScript(
      "Object.getPrototypeOf(Object.getPrototypeOf(childNode)) === Object.getPrototypeOf(baseNode)"
    )

    switch consume prototypeResult {
    case .value(let value):
      let matchesPrototypeChain = value.toBool(in: context)
      #expect(matchesPrototypeChain)
    case .exception:
      Issue.record("Expected JS prototype chain to reflect exported Swift inheritance")
    }
  }
}

@Test func jsClassAutoConvertibleExportsMarkedMethods() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let instance = ExportedFunctionNode(name: "leaf", count: 4)
    global.setProperty(
      instance, forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("node"), in: context)

    let sumResult = context.evaluateScript("node.sum(2, 3)")
    switch consume sumResult {
    case .value(let value):
      #expect(value.toDouble(in: context) == 9)
    case .exception:
      Issue.record("Expected exported JSClass method to be callable from JavaScript")
    }

    let customNameResult = context.evaluateScript("node.loudLabel('seed', 1)")
    switch consume customNameResult {
    case .value(let value):
      #expect(value.toString(in: context) == "SEED:leaf:on")
    case .exception:
      Issue.record(
        "Expected exported JSClass method to honor custom function name and argument converters")
    }

    let returnCoderResult = context.evaluateScript("node.payload()")
    switch consume returnCoderResult {
    case .value(let value):
      #expect(value.toDouble(in: context) == 8)
    case .exception:
      Issue.record("Expected exported JSClass method to honor custom return encoder")
    }

    let errorCoderResult = context.evaluateScript("node.fail()")
    switch consume errorCoderResult {
    case .value:
      Issue.record("Expected throwing exported JSClass method to surface a JavaScript exception")
    case .exception(let value):
      #expect(value.toString(in: context) == "bad")
    }
  }
}
