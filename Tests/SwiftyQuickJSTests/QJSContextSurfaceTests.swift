import Testing

@testable import SwiftyQuickJS

private enum QJSContextSurfaceDataKey: JSContextDataKey {
  typealias Value = String
}

/// The concrete QJS context actor and VM (S8): creation/teardown, the context
/// data box, the context-lifetime default scope, `Hashable` identity, and the
/// manual `makeScope` factory.
///
/// `QJSValue` is `~Copyable` and non-`Sendable`, so every read happens inside
/// an isolated helper or an `withInstantContext` window.
private func makeDurableValueAndWindowValue(
  on context: isolated QJSContext
) -> (durable: String, windowed: String) {
  let durable = context.makeString("durable")
  let windowed = context.withInstantContext { scope in
    scope.makeString("windowed").toString()
  }
  return (durable.toString(), windowed)
}

private func makeScopePersistedValue(on context: isolated QJSContext) -> String {
  let scope = context.makeScope()
  let persisted = scope.persist(scope.makeString("persisted"))
  return persisted.toString()
}

@Suite
struct QJSContextSurfaceTests {
  @Test
  func createsAndTearsDownAContextOnItsVirtualMachine() async {
    let virtualMachine = QJSVirtualMachine()
    do {
      let context = QJSContext(virtualMachine: virtualMachine)
      let window = await context.withInstantContext { scope in
        scope.makeNumber(21).toNumber() * 2
      }
      #expect(window == 42)
      virtualMachine.gc()
    }

    // Dropping the context runs the isolated deinit (registry close →
    // default-scope drain → box clear → context release → stack pop) on the
    // VM thread; the VM stays usable afterwards.
    let next = QJSContext(virtualMachine: virtualMachine)
    #expect(next.virtualMachine == virtualMachine)
  }

  @Test
  func contextDataIsStoredInTheInstalledBox() async {
    let context = QJSContext()
    #expect(context.driverContextHandle.contextDataStorageBox() != nil)

    await context.setData("payload", for: QJSContextSurfaceDataKey.self)
    let stored = await context.data(for: QJSContextSurfaceDataKey.self)
    #expect(stored == "payload")

    await context.setData(nil, for: QJSContextSurfaceDataKey.self)
    let cleared = await context.data(for: QJSContextSurfaceDataKey.self)
    #expect(cleared == nil)
  }

  @Test
  func defaultScopeKeepsContextValuesAliveAcrossWindows() async {
    let context = QJSContext()
    let (durable, windowed) = await makeDurableValueAndWindowValue(on: context)

    // The window drained before this read; only the context default scope can
    // still be holding the reference.
    #expect(windowed == "windowed")
    #expect(durable == "durable")
  }

  @Test
  func manualScopePersistsIntoTheDefaultScope() async {
    let context = QJSContext()
    let persisted = await makeScopePersistedValue(on: context)
    #expect(persisted == "persisted")
  }

  @Test
  func hashableIdentityFollowsTheEngineHandles() {
    let virtualMachine = QJSVirtualMachine()
    let otherVirtualMachine = QJSVirtualMachine()
    let context = QJSContext(virtualMachine: virtualMachine)
    let sibling = QJSContext(virtualMachine: virtualMachine)

    #expect(context == context)
    #expect(context.hashValue == context.hashValue)
    #expect(context != sibling)
    #expect(context.virtualMachine == virtualMachine)
    #expect(context.virtualMachine != otherVirtualMachine)
    #expect(virtualMachine != otherVirtualMachine)
    #expect(virtualMachine.hashValue == virtualMachine.hashValue)
  }
}
