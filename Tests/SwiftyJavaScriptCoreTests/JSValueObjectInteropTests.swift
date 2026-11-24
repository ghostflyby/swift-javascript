import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreValueHandleStoresHandleAndContextDirectly() async {
  let context = JSCContext(virtualMachine: JSCVirtualMachine())

  await context.withInstantContext { scope in
    let value = scope.makeNumber(42)
    let handle = value.borrowHandle()
    let stored = JSCValue(handle: handle, contextHandle: scope.driverContextHandle)
    #expect(stored.borrowHandle().ref == handle.ref)
    #expect(stored.contextHandle == scope.driverContextHandle)
    // `value` and `stored` are non-owning views over the same
    // arena-owned reference.
  }
}
