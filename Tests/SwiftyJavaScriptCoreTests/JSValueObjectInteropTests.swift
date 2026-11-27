import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreValueStoresRefAndContextDirectly() async {
  let context = await JSCContext(
    virtualMachine: await JSCVirtualMachine(.nonblocking), .nonblocking)

  await context.withInstantContext { scope in
    let value = scope.makeNumber(42)
    let stored = JSCValue(ref: value.ref, contextRef: scope.contextRef)
    #expect(stored.ref == value.ref)
    #expect(stored.contextRef == scope.contextRef)
    // `value` and `stored` are non-owning views over the same
    // arena-owned reference.
  }
}
