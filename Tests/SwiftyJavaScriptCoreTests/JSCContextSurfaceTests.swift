import Testing

@testable import SwiftyJavaScriptCore

private enum JSCContextSurfaceDataKey: JSContextDataKey {
  typealias Value = String
}

/// The concrete JSC context actor and VM (S8): creation/teardown, the context
/// data box, the context-lifetime default scope, `Hashable` identity, and the
/// manual `makeScope` factory.
///
/// `JSCValue` is `~Copyable` and non-`Sendable`, so — exactly like the legacy
/// context — values never cross the actor boundary in a test: every read
/// happens inside an isolated helper or an `withInstantContext` window.
private func makeDurableValueAndWindowValue(
  on context: isolated JSCContext
) -> (durable: String, windowed: String) {
  let durable = context.makeString("durable")
  let windowed = context.withInstantContext { scope in
    scope.makeString("windowed").toString()
  }
  return (durable.toString(), windowed)
}

private func makeScopePersistedValue(on context: isolated JSCContext) -> String {
  let scope = context.makeScope()
  let persisted = scope.persist(scope.makeString("persisted"))
  return persisted.toString()
}

@Suite
struct JSCContextSurfaceTests {
  @Test
  func createsAndTearsDownAContextOnItsVirtualMachine() async {
    let virtualMachine = JSCVirtualMachine()
    do {
      let context = JSCContext(virtualMachine: virtualMachine)
      let window = await context.withInstantContext { scope in
        scope.makeNumber(21).toNumber() * 2
      }
      #expect(window == 42)
    }

    // Dropping the context runs the isolated deinit (registry close →
    // default-scope drain → box clear → context release → stack pop) on the
    // VM thread; the VM stays usable afterwards.
    let next = JSCContext(virtualMachine: virtualMachine)
    #expect(next.virtualMachine == virtualMachine)
  }

  @Test
  func contextDataIsStoredInTheInstalledBox() async {
    let context = JSCContext()
    #expect(context.driverContextHandle.contextDataStorageBox() != nil)

    await context.setData("payload", for: JSCContextSurfaceDataKey.self)
    let stored = await context.data(for: JSCContextSurfaceDataKey.self)
    #expect(stored == "payload")

    await context.setData(nil, for: JSCContextSurfaceDataKey.self)
    let cleared = await context.data(for: JSCContextSurfaceDataKey.self)
    #expect(cleared == nil)
  }

  @Test
  func defaultScopeKeepsContextValuesAliveAcrossWindows() async {
    let context = JSCContext()
    let (durable, windowed) = await makeDurableValueAndWindowValue(on: context)

    // The window drained before this read; only the context default scope can
    // still be holding the value.
    #expect(windowed == "windowed")
    #expect(durable == "durable")
  }

  @Test
  func manualScopePersistsIntoTheDefaultScope() async {
    let context = JSCContext()
    let persisted = await makeScopePersistedValue(on: context)
    #expect(persisted == "persisted")
  }

  @Test
  func hashableIdentityFollowsTheEngineHandles() {
    let virtualMachine = JSCVirtualMachine()
    let otherVirtualMachine = JSCVirtualMachine()
    let context = JSCContext(virtualMachine: virtualMachine)
    let sibling = JSCContext(virtualMachine: virtualMachine)

    #expect(context == context)
    #expect(context.hashValue == context.hashValue)
    #expect(context != sibling)
    #expect(context.virtualMachine == virtualMachine)
    #expect(context.virtualMachine != otherVirtualMachine)
    #expect(virtualMachine != otherVirtualMachine)
    #expect(virtualMachine.hashValue == virtualMachine.hashValue)
  }
}
