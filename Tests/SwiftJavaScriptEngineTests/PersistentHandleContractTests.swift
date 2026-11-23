import Testing

@testable import SwiftJavaScript

// MARK: - Negative compile examples (not automatable in Swift Testing)
//
// 「handle 自身不提供解析」是编译期契约(设计 §1.4/§5.1:持有不授权访问);
// Swift Testing 无法在测试内断言编译期失败,以下样例仅以文档形式保留,
// 标注「应编译失败」,该验证未自动化:
//
//     // ✗ 应编译失败 —— `JSPersistentHandle` 没有 resolve 方法:
//     let value = handle.resolve()
//
//     // ✗ 应编译失败 —— 解析产物是 `JSValue`,非 Sendable,不能离开
//     // actor 隔离域直接返回给 nonisolated 上下文:
//     func leak(_ context: JSContext<JavaScriptCoreEngine>) async {
//       guard let value = await context.resolve(handle) else { return }
//       _ = value
//     }
//
// 正例见下方 `persistentHandleRoundTripsAcrossSynchronousWindows`:解析发生
// 在 `withInstantContext` / `withIsolatedGlobalObject` 的同步窗口内。
//
// MARK: - Contract

/// Stage 4 persistent-handle contract, parameterized over both engines
/// (`docs/PERSISTENT_HANDLE_DESIGN.md` §8.2).
///
/// The core layer needs no backend additions: mint and resolve are built from
/// the existing `claimOwnedValueHandle` / `rootOwnedValueHandle` /
/// `unrootOwnedValueHandle` / `releaseCreatedHandle` requirements, and each
/// backend already implements them (JSC: protect/unprotect + identity claim;
/// QuickJS: `JS_DupValue` / `JS_FreeValue` with identity rooting).
@Suite
struct PersistentHandleContractTests {
  @Test(arguments: ScriptEngine.allCases)
  func persistentHandleRoundTripsAcrossSynchronousWindows(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleRoundTripsAcrossWindows.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func persistentBindingKeepsValueAliveAcrossCollection(_ engine: ScriptEngine) async {
    await engine.run(PersistentBindingSurvivesCollection.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func persistentHandleIsContextLocalAndDiesWithContainer(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleIsContextLocal.self)
  }

  /// Same runtime, two contexts: each context has its own registry, so a
  /// handle resolves only in the context that minted it and neither
  /// context's binding is disturbed by the other.
  @Test(arguments: ScriptEngine.allCases)
  func persistentHandlesDoNotCrossContextBoundaries(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandlesDoNotCrossContext.self)
  }

  /// The two failure shapes that must be ordinary `nil` values rather than
  /// dangling identities: a binding that no longer exists (dead identity or
  /// unreachable registry) and a container that has been destroyed.
  @Test(arguments: ScriptEngine.allCases)
  func persistentHandleWithoutBindingOrContainerYieldsNil(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleWithoutBinding.self)
  }

  /// Design §8.1 case 8, foreign-thread form: the storage box is cleared and
  /// reinstalled from outside the VM thread. The engine-side swap must not
  /// run on the calling thread — it is posted to the VM thread, ahead of
  /// anything enqueued after it (the FIFO sentinel).
  @Test(arguments: ScriptEngine.allCases)
  func contextDataStorageBoxSwapFromForeignThreadStaysOnVMThread(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleForeignThreadBoxSwap.self)
  }

  /// GC engine half of design §4.4's rewritten acceptance: while a binding
  /// is alive its root (JSC protect / QuickJS duplicate) keeps a collectible
  /// object resolvable across a forced collection.
  @Test(arguments: ScriptEngine.allCases)
  func persistentBindingSurvivesForcedCollection(_ engine: ScriptEngine) async {
    await engine.run(PersistentBindingSurvivesForcedCollection.self)
  }

  /// Reference-counted half: once invalidated and settled, the binding's
  /// duplicate is gone and QuickJS collects the value even though a JS
  /// `WeakRef` witnesses it. JSC cannot express this through its C API
  /// (design §4.4: no host-side weak reference), so it runs QuickJS only.
  @Test
  func persistentBindingReleasePermitsCollectionOnQuickJS() async {
    await ScriptEngine.quickJS.run(PersistentBindingReleasePermitsCollection.self)
  }

  /// Dropping the last owner must settle through the VM's serial executor,
  /// not inline on the releasing thread: after the FIFO sentinel the slot is
  /// back on the free list, so the next mint reuses it with a new generation.
  @Test(arguments: ScriptEngine.allCases)
  func persistentHandleDeinitSettlesThroughVMExecutor(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleDeinitSettlement.self)
  }

  /// ABA guard: after the slot is recycled, the old identity keeps its old
  /// generation and must not resolve the new binding.
  @Test(arguments: ScriptEngine.allCases)
  func persistentHandleGenerationRejectsStaleIdentity(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleGeneration.self)
  }

  /// `Sendable` is the handle's reason to exist: it crosses actor isolation
  /// domains while the local `JSValue` cannot, and resolves after the hop.
  @Test(arguments: ScriptEngine.allCases)
  func persistentHandleCrossesActorIsolationDomains(_ engine: ScriptEngine) async {
    await engine.run(PersistentHandleCrossesIsolation.self)
  }

  /// Contexts are created on the VM thread even when `JSContext.init` runs
  /// from another thread while that thread is busy with the VM's other
  /// contexts (design §0.2.3). QuickJS used to crash intermittently in
  /// `JS_FreeContext` / `JS_RunGC` when a context was created off the VM
  /// thread while another one was settling.
  @Test(arguments: ScriptEngine.allCases)
  func contextsOnABusySharedVMCanBeCreatedFromAnyThread(_ engine: ScriptEngine) async {
    await engine.run(ContextsOnABusySharedVM.self)
  }

  /// Prepared scripts and property keys retain the engine context and can
  /// die on any thread; their release is routed to the VM thread.
  @Test(arguments: ScriptEngine.allCases)
  func selfOwningInputsDroppedOffTheVMThreadReleaseCleanly(_ engine: ScriptEngine) async {
    await engine.run(SelfOwningInputsDroppedOffTheVMThread.self)
  }
}

/// FIFO sentinel on the context's executor: pinging after the context's last
/// release observes the asynchronously scheduled isolated deinit (same
/// pattern as the Mock tests' `IsolatedDeinitBarrier`).
///
/// The stateful counter is load-bearing, not decoration: an empty actor
/// method with a custom executor was observed to be optimized into a
/// non-hopping call (~4 ns instead of a cross-thread round trip), which made
/// the sentinel observe nothing. Mutating actor state forces the isolation
/// hop, and `pingCount()` makes the write observable; see
/// `Benchmarks/PersistentHandleBenchmarks/BenchmarkMain.swift`.
private actor PersistentHandleBarrier {
  nonisolated let unownedExecutor: UnownedSerialExecutor
  private var pings = 0

  init<E: JSEngine>(virtualMachine: JSVirtualMachine<E>) {
    self.unownedExecutor = virtualMachine.unownedExecutor
  }

  func ping() {
    pings &+= 1
  }

  func pingCount() -> Int { pings }
}

private func awaitPersistentHandleSettlement<E: JSEngine>(
  on virtualMachine: JSVirtualMachine<E>
) async {
  let barrier = PersistentHandleBarrier(virtualMachine: virtualMachine)
  await barrier.ping()
  _ = await barrier.pingCount()
}

private enum PersistentHandleRoundTripsAcrossWindows: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    // Mint inside the callback window and carry only the Sendable handle out.
    let handle = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("persisted"))
    }

    // A later window resolves a copy into its own arena.
    let text = await context.withInstantContext { scope in
      guard let value = scope.resolve(handle) else { return "<nil>" }
      return scope.toString(value)
    }
    #expect(text == "persisted")

    #expect(handle.invalidate())
    #expect(handle.invalidate() == false)

    // The identity is dead immediately, independent of the settlement turn.
    let deadAfterInvalidate = await context.withInstantContext { scope in
      scope.resolve(handle) == nil
    }
    #expect(deadAfterInvalidate)
  }
}

private enum PersistentBindingSurvivesCollection: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    let handle = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeNumber(41.5))
    }

    // The binding's own root must keep the value alive with no scope holding
    // it. JSC collects here; QuickJS needs no collection hook (the binding
    // owns a duplicated reference).
    let number = await context.withIsolatedGlobalObject { isolatedContext, _ in
      stage3CollectGarbageIfSupported(isolatedContext.driverContextHandle)
      guard let value = isolatedContext.resolve(handle) else { return -1.0 }
      return value.toNumber(in: isolatedContext)
    }
    #expect(number == 41.5)
  }
}

private enum PersistentHandleIsContextLocal: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    // Cross-context: same VM, different registry -> nil.
    let first = JSContext<E>()
    let handle = await first.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("local"))
    }
    let second = JSContext(virtualMachine: first.virtualMachine)
    let foreignResolved = await second.withInstantContext { scope in
      scope.resolve(handle) == nil
    }
    #expect(foreignResolved)

    // Container death: the surviving handle is a dead identity, not a
    // dangling reference.
    var optionalContext: JSContext<E>? = JSContext()
    let virtualMachine = optionalContext!.virtualMachine
    let dyingHandle = await optionalContext!.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("doomed"))
    }
    optionalContext = nil
    await awaitPersistentHandleSettlement(on: virtualMachine)
    #expect(dyingHandle.invalidate() == false)

    // The engine is still usable: the registry settled its references before
    // the context was released, so a fresh context on the same VM works. The
    // settlement barrier already drained the VM executor, so this creation on
    // an idle VM is race-free.
    let survivor = JSContext<E>(virtualMachine: virtualMachine)
    let roundTrip = await survivor.withInstantContext { scope -> Double in
      switch scope.evaluateScript("1 + 2") {
      case .value(let value):
        return value.toNumber(in: scope)
      case .exception:
        return -1
      }
    }
    #expect(roundTrip == 3)
  }
}

// MARK: - Cross-context isolation

private enum PersistentHandlesDoNotCrossContext: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let first = JSContext<E>()
    // Same runtime, second context: registry IDs differ, so identities are
    // context-local even though the engines would accept cross-context values
    // inside one group/runtime (design §5.4/§6.2).
    let second = JSContext(virtualMachine: first.virtualMachine)

    let firstHandle = await first.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("first"))
    }
    let secondHandle = await second.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("second"))
    }
    #expect(firstHandle.identity.registry != secondHandle.identity.registry)

    let firstText = await first.withInstantContext { scope -> String in
      guard let value = scope.resolve(firstHandle) else { return "<nil>" }
      return scope.toString(value)
    }
    let secondText = await second.withInstantContext { scope -> String in
      guard let value = scope.resolve(secondHandle) else { return "<nil>" }
      return scope.toString(value)
    }
    #expect(firstText == "first")
    #expect(secondText == "second")

    // No cross-talk in either direction.
    let firstSeesSecond = await first.withInstantContext { scope in
      scope.resolve(secondHandle) == nil
    }
    let secondSeesFirst = await second.withInstantContext { scope in
      scope.resolve(firstHandle) == nil
    }
    #expect(firstSeesSecond)
    #expect(secondSeesFirst)

    // Both bindings stay valid afterwards: the rejected lookups are pure
    // misses, not accidental invalidation.
    let firstStillValid = await first.withInstantContext { scope in
      scope.resolve(firstHandle) != nil
    }
    let secondStillValid = await second.withInstantContext { scope in
      scope.resolve(secondHandle) != nil
    }
    #expect(firstStillValid)
    #expect(secondStillValid)
  }
}

// MARK: - Nil without a binding or without a container

private enum PersistentHandleWithoutBinding: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    // Live binding, but the synchronous registry access path (the context
    // data box) is removed. Scope-side resolution must return nil; the actor
    // path owns the registry directly and keeps working.
    let handle = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("detached"))
    }
    guard let box = context.driverContextHandle.contextDataStorageBox() else {
      Issue.record("JSContext did not install a context data storage box")
      return
    }
    await context.withInstantContext { _ in
      context.driverContextHandle.installContextDataStorageBox(nil)
    }
    let scopeWithoutBox = await context.withInstantContext { scope in
      scope.resolve(handle) == nil
    }
    let actorWithRegistry = await context.withIsolatedGlobalObject { isolatedContext, _ in
      isolatedContext.resolve(handle) != nil
    }
    #expect(scopeWithoutBox)
    #expect(actorWithRegistry)
    await context.withInstantContext { _ in
      context.driverContextHandle.installContextDataStorageBox(box)
    }

    // Dead identity: metadata dies immediately, independent of the pump.
    #expect(handle.invalidate())
    let deadResolved = await context.withInstantContext { scope in
      scope.resolve(handle) == nil
    }
    #expect(deadResolved)

    // Container death: the surviving handle stays a dead identity, and a
    // rebuilt context on the same runtime cannot resolve it (registryID
    // mismatch). Neither operation dangles or crashes.
    var dying: JSContext<E>? = JSContext()
    let virtualMachine = dying!.virtualMachine
    let dyingHandle = await dying!.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("doomed"))
    }
    dying = nil
    await awaitPersistentHandleSettlement(on: virtualMachine)
    #expect(dyingHandle.invalidate() == false)

    // The settlement barrier has drained the VM executor, so this creation on
    // an idle VM is race-free.
    let survivor = JSContext<E>(virtualMachine: virtualMachine)
    let survivorResolved = await survivor.withInstantContext { scope in
      scope.resolve(dyingHandle) == nil
    }
    #expect(survivorResolved)
  }
}

/// The box is cleared and reinstalled with no actor window: the calls come
/// from the test's own thread. Scope-side resolution goes away and comes
/// back; the actor side, which owns the registry, is never disturbed.
/// Under ASan this is the real-engine form of "no engine call on the
/// calling thread" for the posted swap.
private enum PersistentHandleForeignThreadBoxSwap: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let virtualMachine = context.virtualMachine

    let handle = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("boxed"))
    }
    // An engine read: taken inside the actor window.
    let box = await context.withInstantContext { scope in
      scope.driverContextHandle.contextDataStorageBox()
    }
    guard let box else {
      Issue.record("JSContext did not install a context data storage box")
      return
    }

    context.driverContextHandle.installContextDataStorageBox(nil)
    await awaitPersistentHandleSettlement(on: virtualMachine)
    let scopeWithoutBox = await context.withInstantContext { scope in
      scope.resolve(handle) == nil
    }
    let actorKeepsRegistry = await context.withIsolatedGlobalObject { isolatedContext, _ in
      isolatedContext.resolve(handle) != nil
    }
    #expect(scopeWithoutBox)
    #expect(actorKeepsRegistry)

    context.driverContextHandle.installContextDataStorageBox(box)
    await awaitPersistentHandleSettlement(on: virtualMachine)
    let scopeRestored = await context.withInstantContext { scope in
      scope.resolve(handle) != nil
    }
    #expect(scopeRestored)
  }
}

private enum ContextsOnABusySharedVM: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let virtualMachine = JSVirtualMachine<E>()
    let resident = JSContext<E>(virtualMachine: virtualMachine)

    // The VM thread keeps working for the resident context in small jobs…
    async let churn: Void = keepBusy(resident, rounds: 200)
    // …while contexts are created and dropped from the test's thread.
    for _ in 0..<100 {
      let shortLived = JSContext<E>(virtualMachine: virtualMachine)
      _ = shortLived
    }
    await churn

    let residentStillWorks = await resident.withInstantContext { scope -> Bool in
      let result = scope.evaluateScript("1 + 1")
      switch consume result {
      case .value(let value):
        return value.toNumber(in: scope) == 2
      case .exception:
        return false
      }
    }
    #expect(residentStillWorks)
  }

  static func keepBusy<E: JSEngine>(_ context: JSContext<E>, rounds: Int) async {
    for _ in 0..<rounds {
      await context.withInstantContext { scope in
        _ = scope.evaluateScript("1 + 1")
      }
    }
  }
}

private enum SelfOwningInputsDroppedOffTheVMThread: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let virtualMachine = context.virtualMachine

    // Created on the VM thread, dropped here on the test's thread: each
    // release may be the engine context's last reference.
    _ = await context.prepareScript("6 * 7")
    _ = await context.makePropertyStringKey("answer")
    await awaitPersistentHandleSettlement(on: virtualMachine)

    let stillWorks = await context.withInstantContext { scope -> Bool in
      let result = scope.evaluateScript("6 * 7")
      switch consume result {
      case .value(let value):
        return value.toNumber(in: scope) == 42
      case .exception:
        return false
      }
    }
    #expect(stillWorks)
  }
}

// MARK: - Collection (design §4.4 rewritten acceptance)

/// Both engines: a live binding roots a collectible object, so a forced
/// collection cannot take it away.
private enum PersistentBindingSurvivesForcedCollection: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let virtualMachine = context.virtualMachine

    let handle = await context.withInstantContext { scope -> JSPersistentHandle<E> in
      let made = scope.makeObject()
      switch consume made {
      case .value(let object):
        object.setProperty(scope.makeString("probe"), forKey: "kind")
        return scope.makePersistentHandle(object)
      case .exception:
        Issue.record("scope.makeObject() failed; using a fallback binding")
        return scope.makePersistentHandle(scope.makeString("fallback"))
      }
    }

    // No scope holds the object when collection runs: only the binding's own
    // root (and, on JSC, the conservative stack scan of the live frame) can
    // keep the property readable.
    let kind = await context.withInstantContext { scope -> String in
      stage4CollectGarbage(
        in: virtualMachine, contextHandle: scope.driverContextHandle)
      guard let value = scope.resolve(handle) else { return "<nil>" }
      return scope.toString(value.getProperty(forKey: "kind", in: scope))
    }
    #expect(kind == "probe")
  }
}

/// QuickJS: releasing the binding removes its duplicate, so a JS `WeakRef`
/// witness turns `undefined` after the cycle collector runs. JSC is excluded
/// because its C API exposes no host-side weak reference (design §4.4), and a
/// `WeakRef` target that the host ever touched cannot be observed as
/// collected (verified with a standalone `JSGarbageCollect` probe during
/// design).
private enum PersistentBindingReleasePermitsCollection: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let virtualMachine = context.virtualMachine
    let mintBox = PersistentHandleMintBox<E>()

    await context.withInstantContext { scope in
      let mint = scope.makeFunction(named: "stage4MintProbe") { c, _, arguments in
        let minted = arguments.withValue(at: 0, in: c) { value in
          c.makePersistentHandle(value)
        }
        mintBox.handle = minted
        return JSCallbackReturn(temporary: c.makeUndefined().handle)
      }
      scope.withGlobalObject { global in
        global.setProperty(mint, forKey: "stage4MintProbe", in: scope)
      }
      let setup = scope.evaluateScript(
        """
        globalThis.__stage4Probe = { kind: "probe" };
        globalThis.__stage4Weak = new WeakRef(globalThis.__stage4Probe);
        stage4MintProbe(globalThis.__stage4Probe);
        delete globalThis.__stage4Probe;
        delete globalThis.stage4MintProbe;
        """)
      switch consume setup {
      case .value:
        break
      case .exception(let exception):
        Issue.record("persistent probe setup failed: \(exception.toString(in: scope))")
      }
    }

    guard let handle = mintBox.handle else {
      Issue.record("the native probe callback did not mint a handle")
      return
    }

    // The binding's duplicate keeps the object alive across a forced cycle
    // collection with no JS-visible strong reference.
    await context.withInstantContext { scope in
      stage4CollectGarbage(
        in: virtualMachine, contextHandle: scope.driverContextHandle)
    }
    let aliveKind = await context.withInstantContext { scope -> String in
      guard let value = scope.resolve(handle) else { return "<nil>" }
      return scope.toString(value.getProperty(forKey: "kind", in: scope))
    }
    #expect(aliveKind == "probe")

    #expect(handle.invalidate())
    await awaitPersistentHandleSettlement(on: virtualMachine)
    // Two collection turns: the first may only reach the sweep phase that
    // frees the binding's last reference, the second clears the weak record.
    for _ in 0..<2 {
      await context.withInstantContext { scope in
        stage4CollectGarbage(
          in: virtualMachine, contextHandle: scope.driverContextHandle)
      }
    }
    let collected = await context.withInstantContext { scope -> Bool in
      let result = scope.evaluateScript(
        "globalThis.__stage4Weak.deref() === undefined")
      switch consume result {
      case .value(let value):
        return scope.toBoolean(value)
      case .exception:
        return false
      }
    }
    #expect(collected)
  }
}

/// A box for carrying the handle out of a synchronous callback (the callback
/// cannot return a handle). Written and read on the VM executor only.
private final class PersistentHandleMintBox<E: JSEngineRuntimeDriver>: @unchecked Sendable {
  var handle: JSPersistentHandle<E>?
}

// MARK: - Automatic cleanup through the VM executor

private enum PersistentHandleDeinitSettlement: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let virtualMachine = context.virtualMachine

    var handle: JSPersistentHandle<E>? = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("settle"))
    }
    guard let identity = handle?.identity else {
      Issue.record("failed to mint a persistent handle")
      return
    }

    // Release the only owner: settlement must be scheduled on the executor,
    // not run inline in deinit (which may execute on any thread).
    handle = nil
    await awaitPersistentHandleSettlement(on: virtualMachine)

    // The sentinel orders after the cleanup job. If the slot were still
    // live/pending, the next mint would take a fresh slot instead of reusing
    // this one and the generation would not advance.
    let replacement = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("replacement"))
    }
    #expect(replacement.identity.slot == identity.slot)
    #expect(replacement.identity.generation > identity.generation)

    let replacementText = await context.withInstantContext { scope -> String in
      guard let value = scope.resolve(replacement) else { return "<nil>" }
      return scope.toString(value)
    }
    #expect(replacementText == "replacement")
    #expect(replacement.invalidate())
  }
}

// MARK: - Generation (ABA)

private enum PersistentHandleGeneration: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let virtualMachine = context.virtualMachine

    let first = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("first"))
    }
    let firstSlot = first.identity.slot
    let firstGeneration = first.identity.generation
    #expect(first.invalidate())
    await awaitPersistentHandleSettlement(on: virtualMachine)

    let second = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("second"))
    }
    #expect(second.identity.slot == firstSlot)
    #expect(second.identity.generation > firstGeneration)

    // The slot is live again, so a `nil` here can only come from the
    // generation comparison, not from state or bounds.
    let staleResolved = await context.withInstantContext { scope in
      scope.resolve(first) == nil
    }
    let freshText = await context.withInstantContext { scope -> String in
      guard let value = scope.resolve(second) else { return "<nil>" }
      return scope.toString(value)
    }
    #expect(staleResolved)
    #expect(freshText == "second")
  }
}

// MARK: - Sendable across isolation domains

private actor PersistentHandleMailbox<E: JSEngineRuntimeDriver> {
  private var stored: JSPersistentHandle<E>?

  func deposit(_ handle: JSPersistentHandle<E>) {
    stored = handle
  }

  func withdraw() -> JSPersistentHandle<E>? {
    stored
  }
}

private enum PersistentHandleCrossesIsolation: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()
    let handle = await context.withInstantContext { scope in
      scope.makePersistentHandle(scope.makeString("sendable"))
    }

    // Two hops between distinct isolation domains; the handle (not the local
    // value) is what travels.
    let inbox = PersistentHandleMailbox<E>()
    let outbox = PersistentHandleMailbox<E>()
    await inbox.deposit(handle)
    guard let staged = await inbox.withdraw() else {
      Issue.record("inbox lost the handle")
      return
    }
    await outbox.deposit(staged)
    guard let recovered = await outbox.withdraw() else {
      Issue.record("outbox lost the handle")
      return
    }
    #expect(recovered == handle)

    // The receiving side resolves the recovered handle back into a local view.
    let text = await context.withInstantContext { scope -> String in
      guard let value = scope.resolve(recovered) else { return "<nil>" }
      return scope.toString(value)
    }
    #expect(text == "sendable")
  }
}
