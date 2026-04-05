import Testing

@testable import SwiftyJavaScriptCore

@Test func jsValueCallSupportsThisAndArguments() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let functionResult = context.evaluateScript("(function(a, b) { return this.base + a + b })")

    switch consume functionResult {
    case .value(let function):
      let thisObject = JSValue(objectIn: context)
      thisObject.setProperty(10, forKey: JSStringManaged("base"), in: context)

      let callResult = function.call(this: thisObject, arguments: 1, 2, in: context)
      switch consume callResult {
      case .value(let value):
        #expect(value.toDouble(in: context) == 13)
      case .exception:
        Issue.record("Expected function.call to succeed")
      }
    case .exception:
      Issue.record("Expected callable function value")
    }
  }
}

@Test func jsValueConstructCreatesObject() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let constructorResult = context.evaluateScript(
      "(function Person(name) { this.name = name; this.kind = 'person' })"
    )

    switch consume constructorResult {
    case .value(let constructor):
      let constructResult = constructor.construct(arguments: "alice", in: context)
      switch consume constructResult {
      case .value(let instance):
        let isObject = instance.isObject(in: context)
        let name = instance.getProperty(forKey: JSStringManaged("name"), in: context).toString(
          in: context)
        let kind = instance.getProperty(forKey: JSStringManaged("kind"), in: context).toString(
          in: context)
        #expect(isObject)
        #expect(name == "alice")
        #expect(kind == "person")
      case .exception:
        Issue.record("Expected constructor.construct to succeed")
      }
    case .exception:
      Issue.record("Expected constructor function value")
    }
  }
}

@Test func jsValueInvokeMethodUsesReceiverAndSurfacesErrors() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let objectResult = context.evaluateScript(
      "({ scale: 4, mul(value) { return this.scale * value } })")

    switch consume objectResult {
    case .value(let object):
      let invokeResult = object.invokeMethod(JSStringManaged("mul"), arguments: 5, in: context)
      switch consume invokeResult {
      case .value(let value):
        #expect(value.toDouble(in: context) == 20)
      case .exception:
        Issue.record("Expected method invocation to succeed")
      }

      let missingResult = object.invokeMethod(JSStringManaged("missing"), in: context)
      switch consume missingResult {
      case .value:
        Issue.record("Expected missing method invocation to raise exception")
      case .exception(let exception):
        let isObject = exception.isObject(in: context)
        #expect(isObject)
      }
    case .exception:
      Issue.record("Expected object literal value")
    }
  }
}
