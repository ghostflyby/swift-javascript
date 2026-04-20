import Testing

@testable import SwiftyJavaScriptCore

@Test func virtualMachineHashableAndIdentity() {
  let vm1 = JSVirtualMachine<JavaScriptCoreEngine>()
  let vm2 = JSVirtualMachine<JavaScriptCoreEngine>()

  #expect(vm1 == vm1)
  #expect(vm1 != vm2)
  #expect(vm1.hashValue == vm1.hashValue)
}

@Test func contextHashableAndGlobalObject() async {
  let vm = JSVirtualMachine<JavaScriptCoreEngine>()
  let context1 = JSContext(virtualMachine: vm)
  let context2 = JSContext(virtualMachine: vm)

  #expect(context1 == context1)
  #expect(context1 != context2)

  await context1.withIsolatedGlobalObject { context, global in
    let isObject = global.isObject(in: context)
    let type = global.type(in: context)
    #expect(isObject)
    #expect(type == .object)
  }
}

@Test func valuesCanBeUsedAcrossContextsInSameVirtualMachine() {
  let vm = JSVirtualMachine<JavaScriptCoreEngine>()
  let sourceContext = JSContext(virtualMachine: vm)
  let targetContext = JSContext(virtualMachine: vm)

  let sourceInstant = JSInstantContext<JavaScriptCoreEngine>(
    ctx: sourceContext.javaScriptCoreContextRef)
  let targetInstant = JSInstantContext<JavaScriptCoreEngine>(
    ctx: targetContext.javaScriptCoreContextRef)
  let value = JSValue(number: 7, in: sourceInstant)

  #expect(value.toDouble(in: targetInstant) == 7)
}
