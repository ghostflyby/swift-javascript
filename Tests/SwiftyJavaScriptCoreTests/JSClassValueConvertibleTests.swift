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

@Test func jsClassAutoConvertibleRoundTripsReferenceIdentity() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let instance = ExportedLeafNode(base: 1, child: "leaf", enabled: true)
    global.setProperty(instance, forKey: JSStringManaged("node"), in: context)

    let decoded: ExportedLeafNode = global.getProperty(
      forKey: JSStringManaged("node"),
      using: JSClassValueConverter<ExportedLeafNode>.self,
      in: context
    )

    #expect(decoded === instance)
  }
}

@Test func jsClassAutoConvertibleReflectsInheritedStoredProperties() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let instance = ExportedLeafNode(base: 2, child: "branch", enabled: true)
    global.setProperty(instance, forKey: JSStringManaged("node"), in: context)

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
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  let hasParentClass =
    ExportedChildNode.jsClassDefinition.parentClass?.ref == ExportedBaseNode.jsClass.ref
  let hasLeafParentClass =
    ExportedLeafNode.jsClassDefinition.parentClass?.ref == ExportedChildNode.jsClass.ref
  #expect(hasParentClass)
  #expect(hasLeafParentClass)

  await context.withIsolatedGlobalObject { context, global in
    let base = ExportedBaseNode(base: 1)
    let child = ExportedChildNode(base: 2, child: "two")
    global.setProperty(base, forKey: JSStringManaged("baseNode"), in: context)
    global.setProperty(child, forKey: JSStringManaged("childNode"), in: context)

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
