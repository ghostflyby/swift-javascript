import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreValueHandleStoresHandleAndContextDirectly() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withInstantContext { context in
    let value = JSValue(number: 42, in: context)
    let handle = value.borrowHandle()
    let stored = JSValue<JavaScriptCoreEngine>(handleValue: handle, in: context.driverContextHandle)
    #expect(stored.borrowHandle().ref == handle.ref)
    #expect(stored.contextHandle == context.driverContextHandle)
    // `value` and `stored` are non-owning views over the same
    // arena-owned reference.
  }
}
