import Testing

@testable import SwiftyQuickJS

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

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

/// Exercises the context-level factories, global access, installed-function
/// wrapper and script evaluation: every one of them creates or settles an
/// engine reference on the context default scope, outside any window.
private func exerciseContextValueOperations(
  on context: isolated QJSContext
) -> (read: Double, script: Double, objectKind: JSType) {
  context.setGlobalProperty(context.makeNumber(41), forKey: "answer")
  let read = context.getGlobalProperty(forKey: "answer").toNumber()
  let key = context.makePropertyStringKey("answer")
  let fromKey = context.makeString(from: key).toString()
  let objectKind = context.makeObject().type()

  context.installGlobalFunction(named: "bump") { c, _, arguments in
    let value: Double = arguments.withValue(at: 0, in: c) { $0.toNumber() }
    return c.return(c.persist(c.makeNumber(value + 1)))
  }

  let script: Double
  let scriptResult = context.evaluateScript(
    "bump(answer) + (\(fromKey.count) - \(fromKey.count))")
  switch consume scriptResult {
  case .value(let value):
    script = value.toNumber()
  case .exception:
    script = -1
  }
  return (read, script, objectKind)
}

@Suite
struct QJSContextSurfaceTests {
  @Test
  func createsAndTearsDownAContextOnItsVirtualMachine() async {
    let virtualMachine = await QJSVirtualMachine(.nonblocking)
    do {
      let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)
      let window = await context.withInstantContext { scope in
        scope.makeNumber(21).toNumber() * 2
      }
      #expect(window == 42)
      await virtualMachine.gc()
    }

    // Dropping the context runs the isolated deinit (registry close →
    // default-scope drain → box clear → context release → stack pop) on the
    // VM thread; the VM stays usable afterwards.
    let next = await QJSContext(virtualMachine: virtualMachine, .nonblocking)
    #expect(next.virtualMachine == virtualMachine)
  }

  @Test
  func contextDataIsStoredInTheInstalledBox() async {
    let context = await QJSContext(.nonblocking)
    #expect(context.contextDataStorageBox() != nil)

    await context.setData("payload", for: QJSContextSurfaceDataKey.self)
    let stored = await context.data(for: QJSContextSurfaceDataKey.self)
    #expect(stored == "payload")

    await context.setData(nil, for: QJSContextSurfaceDataKey.self)
    let cleared = await context.data(for: QJSContextSurfaceDataKey.self)
    #expect(cleared == nil)
  }

  @Test
  func defaultScopeKeepsContextValuesAliveAcrossWindows() async {
    let context = await QJSContext(.nonblocking)
    let (durable, windowed) = await makeDurableValueAndWindowValue(on: context)

    // The window drained before this read; only the context default scope can
    // still be holding the reference.
    #expect(windowed == "windowed")
    #expect(durable == "durable")
  }

  @Test
  func manualScopePersistsIntoTheDefaultScope() async {
    let context = await QJSContext(.nonblocking)
    let persisted = await makeScopePersistedValue(on: context)
    #expect(persisted == "persisted")
  }

  @Test
  func contextLevelOperationsSettleOnTheDefaultScope() async {
    let context = await QJSContext(.nonblocking)
    let result = await exerciseContextValueOperations(on: context)
    #expect(result.read == 41)
    #expect(result.script == 42)
    #expect(result.objectKind == .object)
  }

  @Test
  func hashableIdentityFollowsTheEngineHandles() async {
    let virtualMachine = await QJSVirtualMachine(.nonblocking)
    let otherVirtualMachine = await QJSVirtualMachine(.nonblocking)
    let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)
    let sibling = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

    #expect(context == context)
    #expect(context.hashValue == context.hashValue)
    #expect(context != sibling)
    #expect(context.virtualMachine == virtualMachine)
    #expect(context.virtualMachine != otherVirtualMachine)
    #expect(virtualMachine != otherVirtualMachine)
    #expect(virtualMachine.hashValue == virtualMachine.hashValue)
  }

  /// A value created on one context of a VM can be addressed through a
  /// sibling context handle of the same runtime. This is a raw driver
  /// contract (two context handles plus a borrowed value token), so it lives
  /// on the concrete engine rather than in the generic engine tests. The
  /// runtime is created here so every engine call runs on the thread that
  /// recorded QuickJS's stack top.
  @Test
  func valuesAreUsableAcrossContextsOfTheSameRuntime() {
    let runtime = QJSEngine.makeRuntime()
    guard
      let sourceContext = QJSEngine.makeContext(in: runtime),
      let targetContext = QJSEngine.makeContext(in: runtime),
      let value = QJSEngine.makeNumber(7, in: sourceContext)
    else {
      Issue.record("Expected same-runtime context handles to be creatable")
      return
    }
    let borrowed = value
    defer {
      JS_FreeContext(targetContext)
      JS_FreeContext(sourceContext)
      QJSEngine.releaseRuntime(runtime)
    }

    let isCompatible = QJSEngine.isContextCompatibleWith(sourceContext, targetContext)
    let targetValue = QJSEngine.toNumber(borrowed, in: targetContext)
    JS_FreeValue(sourceContext, value)

    #expect(isCompatible)
    #expect(targetValue == 7)
  }
}
