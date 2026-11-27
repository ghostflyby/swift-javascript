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

/// Argument decoder override: uppercases the incoming string.
enum UppercaseStringDecoder: JSValueDecoder {
  typealias SwiftType = String

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> String {
    _ = context
    return value.toString().uppercased()
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

private func makeExportedClassContext() -> JSCInstantContext {
  let runtime = JSContextGroupCreate()!
  guard let contextHandle = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
    fatalError("JSCEngine could not create a context handle")
  }
  return JSCInstantContext(contextRef: contextHandle)
}

@Test func jsClassAutoConvertibleRoundTripsReferenceIdentity() throws {
  let context = makeExportedClassContext()

  let instance = ExportedLeafNode(base: 1, child: "leaf", enabled: true)
  let encoded = try ExportedLeafNode.tryEncode(instance, in: context)
  context.setGlobalProperty(encoded, forKey: "node")

  let decoded = try ExportedLeafNode.tryDecode(encoded, in: context)
  #expect(decoded === instance)
}

@Test func jsClassAutoConvertibleReflectsInheritedStoredProperties() throws {
  let context = makeExportedClassContext()

  let instance = ExportedLeafNode(base: 2, child: "branch", enabled: true)
  let encoded = try ExportedLeafNode.tryEncode(instance, in: context)
  context.setGlobalProperty(encoded, forKey: "node")

  switch context.evaluateScript(
    "String(node.base) + ':' + node.child + ':' + String(node.enabled)")
  {
  case .value(let value):
    #expect(value.toString() == "2:branch:true")
  case .exception:
    Issue.record("Expected class-backed object properties to be readable from JavaScript")
  }

  switch context.evaluateScript(
    "node.base = 9; node.child = 'updated'; node.enabled = false; node.base")
  {
  case .value(let value):
    #expect(value.toNumber() == 9)
  case .exception:
    Issue.record("Expected class-backed object properties to be writable from JavaScript")
  }

  #expect(instance.base == 9)
  #expect(instance.child == "updated")
  #expect(instance.enabled == false)
}

@Test func jsClassAutoConvertibleBuildsJSClassAndPrototypeInheritanceChain() throws {
  let context = makeExportedClassContext()

  #expect(ExportedChildNode.jsClassDefinition.parentClass == .for(ExportedBaseNode.self))
  #expect(ExportedLeafNode.jsClassDefinition.parentClass == .for(ExportedChildNode.self))

  #expect(
    ExportedChildNode.jsClassDefinition.parentClass?.jsClass(in: context).ref
      == ExportedBaseNode.jsClass(in: context).ref
  )
  #expect(
    ExportedLeafNode.jsClassDefinition.parentClass?.jsClass(in: context).ref
      == ExportedChildNode.jsClass(in: context).ref
  )

  let base = ExportedBaseNode(base: 1)
  let encodedBase = try ExportedBaseNode.tryEncode(base, in: context)
  context.setGlobalProperty(encodedBase, forKey: "baseNode")

  let child = ExportedChildNode(base: 2, child: "two")
  let encodedChild = try ExportedChildNode.tryEncode(child, in: context)
  context.setGlobalProperty(encodedChild, forKey: "childNode")

  switch context.evaluateScript(
    "Object.getPrototypeOf(Object.getPrototypeOf(childNode)) === Object.getPrototypeOf(baseNode)"
  ) {
  case .value(let value):
    let matchesPrototypeChain = value.toBoolean()
    #expect(matchesPrototypeChain)
  case .exception:
    Issue.record("Expected JS prototype chain to reflect exported Swift inheritance")
  }
}

@Test func jsClassAutoConvertibleExportsMarkedMethods() throws {
  let context = makeExportedClassContext()

  let instance = ExportedFunctionNode(name: "leaf", count: 4)
  let encoded = try ExportedFunctionNode.tryEncode(instance, in: context)
  context.setGlobalProperty(encoded, forKey: "node")

  switch context.evaluateScript("node.sum(2, 3)") {
  case .value(let value):
    #expect(value.toNumber() == 9)
  case .exception:
    Issue.record("Expected exported class method to be callable from JavaScript")
  }

  switch context.evaluateScript("node.loudLabel('seed', 1)") {
  case .value(let value):
    #expect(value.toString() == "SEED:leaf:on")
  case .exception:
    Issue.record(
      "Expected exported class method to honor custom function name and argument converters")
  }

  switch context.evaluateScript("node.payload()") {
  case .value(let value):
    #expect(value.toNumber() == 8)
  case .exception:
    Issue.record("Expected exported class method to honor custom return encoder")
  }

  switch context.evaluateScript("node.fail()") {
  case .value:
    Issue.record("Expected throwing exported class method to surface a JavaScript exception")
  case .exception(let value):
    #expect(value.toString() == "bad")
  }
}
