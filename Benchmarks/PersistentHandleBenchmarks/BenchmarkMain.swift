import Foundation
import SwiftJavaScript
import SwiftyJavaScriptCore
import SwiftyQuickJS

// Stage 4 calibration harness (docs/PERSISTENT_HANDLE_DESIGN.md §8.4/§11).
//
// Everything below uses the public library surface only: the context `C`,
// `withInstantContext`, `makeScope`, `makePersistentHandle`, `resolve`,
// `invalidate`, and the driver's `toNumberForHandle`. The harness deliberately
// does not reach into the registry, so the measured numbers are the ones a
// host actually pays.
//
// Structural choices that matter for reading the numbers:
// - One VM per engine run; a fresh context per sample. A context's
//   `isolated deinit` runs on the VM's serial executor, so the next sample
//   waits for it through a FIFO sentinel (`ExecutorBarrier`).
// - Values are numbers: both engines represent doubles as immediates, so the
//   measured cost is the wrapper/registry layer, not JS heap allocation.
// - `C.resolve` and `C.Scope.resolve` are the two registry access paths
//   (direct actor property vs context-data box).

@main
struct PersistentHandleBenchmarks {
  static func main() async {
    let arguments = CommandLine.arguments
    let config: BenchConfig = arguments.contains("--quick") ? .quick : .standard
    let reporter = Reporter()
    printEnvironment(config: config)

    let syntheticOnly = arguments.contains("--synthetic-only")
    if !syntheticOnly && !arguments.contains("--quickjs-only") {
      await EngineBenchmarks.run(
        JSCContext.self, name: "JavaScriptCore",
        config: config, reporter: reporter)
    }
    if !syntheticOnly && !arguments.contains("--jsc-only") {
      await EngineBenchmarks.run(
        QJSContext.self, name: "QuickJS",
        config: config, reporter: reporter)
    }
    if !arguments.contains("--no-synthetic") {
      await SyntheticBenchmarks.run(config: config, reporter: reporter)
    }

    reporter.printMarkdown()
    print("\n# done")
  }
}

// MARK: - FIFO sentinel

/// Pinned to a VM's serial executor; `ping()` orders after every job and
/// cleanup closure enqueued before it (same pattern as the contract tests).
///
/// The stateful counter is load-bearing: an **empty** actor method with a
/// custom executor was observed to compile/optimize into a non-hopping call
/// (~4 ns instead of the real ~6 µs cross-thread round trip), which made the
/// sentinel observe nothing and let context teardown race later samples.
/// Mutating actor state forces the isolation hop.
private actor ExecutorBarrier {
  nonisolated let unownedExecutor: UnownedSerialExecutor
  private var pings = 0

  init<VM: JSVirtualMachine>(_ virtualMachine: VM) {
    self.unownedExecutor = virtualMachine.unownedExecutor
  }

  func ping() {
    pings &+= 1
  }

  func pingCount() -> Int { pings }
}

// MARK: - Sample carriers

private struct MintBatch<C: JSContext>: Sendable {
  let nanos: UInt64
  let handles: [C.PersistentHandle]
  let checksum: UInt64
}

private struct ResolveHitTimings: Sendable {
  let witnessDirect: UInt64
  let witnessHit: UInt64
  let actorDirect: UInt64
  let actorHit: UInt64
  let checksum: Double
}

private struct ResolveMissTimings: Sendable {
  let witnessMiss: UInt64
  let actorMiss: UInt64
  let invalidateMiss: UInt64
  let misses: Int
  let discardedInvalidations: Int
}

private struct ResolveSample: Sendable {
  let hit: ResolveHitTimings
  let miss: ResolveMissTimings
}

// MARK: - Engine benchmarks

private enum EngineBenchmarks {
  static func run<C: JSContext>(
    _ context: C.Type,
    name: String,
    config: BenchConfig,
    reporter: Reporter
  ) async {
    _ = context
    let virtualMachine = C.VirtualMachine()
    let barrier = ExecutorBarrier(virtualMachine)

    // A resident context, so every sample context is a second context on a VM
    // that already hosts engine state — the shape hosts create, and the one
    // the §11 numbers were taken with.
    var bootstrapBox: C? = C(virtualMachine: virtualMachine)

    if BenchDebug.enabled {
      let start = monotonicNanos()
      for _ in 0..<1_000 {
        await barrier.ping()
      }
      print(
        String(
          format: "  [debug] ping: %.1f ns; count=%d",
          Double(monotonicNanos() - start) / 1_000.0,
          await barrier.pingCount()))
    }

    print("\n# \(name) allocation")
    await runAllocation(
      name: name, virtualMachine: virtualMachine, bootstrap: bootstrapBox!,
      barrier: barrier, config: config, reporter: reporter)

    print("\n# \(name) resolve and registry lookup")
    await runResolve(
      name: name, virtualMachine: virtualMachine, bootstrap: bootstrapBox!,
      barrier: barrier, config: config, reporter: reporter)

    print("\n# \(name) release")
    await runRelease(
      name: name, virtualMachine: virtualMachine, bootstrap: bootstrapBox!,
      barrier: barrier, config: config, reporter: reporter)

    print("\n# \(name) mass invalidation scaling")
    await runScale(
      name: name, virtualMachine: virtualMachine, bootstrap: bootstrapBox!,
      barrier: barrier, config: config, reporter: reporter)

    // Drop the bootstrap **through the only strong reference** and wait for
    // its isolated deinit. A lingering `let bootstrap` would keep it alive
    // past this point and let `JS_FreeContext` race the VM's `JS_FreeRuntime`.
    bootstrapBox = nil
    await barrier.ping()
  }

  /// Create a fresh context. The surface `init(virtualMachine:)` routes the
  /// engine-side creation to the VM thread itself and waits for it, so the call
  /// is safe from this cooperative thread; `bootstrap` only keeps the resident
  /// context alive.
  private static func makeContext<C: JSContext>(
    _ virtualMachine: C.VirtualMachine,
    via bootstrap: C
  ) async -> C {
    _ = bootstrap
    return C(virtualMachine: virtualMachine)
  }

  // MARK: Allocation

  /// Mint inside a synchronous scope, so only the binding survives: the
  /// source value drains with the scope. The baseline is "create the same
  /// value and let the default scope hold it" — creation + explicit root and
  /// no early-release capability.
  private static func runAllocation<C: JSContext>(
    name: String,
    virtualMachine: C.VirtualMachine,
    bootstrap: C,
    barrier: ExecutorBarrier,
    config: BenchConfig,
    reporter: Reporter
  ) async {
    let ops = config.allocationOps

    func mintSample() async -> UInt64 {
      let context = await makeContext(virtualMachine, via: bootstrap)
      let batch = await mintBatch(context, count: ops)
      var contextBox: C? = context
      contextBox = nil
      await barrier.ping()
      return batch.nanos
    }

    func holdSample() async -> UInt64 {
      let context = await makeContext(virtualMachine, via: bootstrap)
      let nanos = await defaultScopeHold(context, count: ops)
      var contextBox: C? = context
      contextBox = nil
      await barrier.ping()
      return nanos
    }

    let pair = await measurePairedSeries(
      opsPerSample: ops,
      samples: config.samples,
      warmup: config.warmup,
      seed: stableSeed("\(name)/allocation/pair"),
      bootstrapResamples: config.bootstrapResamples,
      candidate: mintSample,
      baseline: holdSample
    )
    reporter.add(
      engine: name, group: "allocation", metric: "handle mint",
      unit: "ns/op", opsPerSample: ops, stats: pair.candidate,
      note: "scope.makePersistentHandle(scope.makeNumber)")
    reporter.add(
      engine: name, group: "allocation", metric: "default scope hold",
      unit: "ns/op", opsPerSample: ops, stats: pair.baseline,
      note: "context.makeNumber (creation + explicit root)")
    print(
      String(
        format:
          "  allocation delta: %+.2f ns/op (mint - default hold)",
        pair.candidate.median - pair.baseline.median))
  }

  private static func mintBatch<C: JSContext>(
    _ context: C,
    count: Int
  ) async -> MintBatch<C> {
    return await context.withInstantContext { scope in
      var handles: [C.PersistentHandle] = []
      handles.reserveCapacity(count)
      var checksum: UInt64 = 0
      let start = monotonicNanos()
      for index in 0..<count {
        let value = scope.makeNumber(Double(index & 0xFFFF))
        let handle = scope.makePersistentHandle(value)
        handles.append(handle)
        checksum &+= UInt64(handles.count)
      }
      let elapsed = monotonicNanos() - start
      return MintBatch(nanos: elapsed, handles: handles, checksum: checksum)
    }
  }

  private static func mintHandles<C: JSContext>(
    _ context: C,
    count: Int
  ) async -> [C.PersistentHandle] {
    await mintBatch(context, count: count).handles
  }

  /// Baseline: create the same value and let the context default scope hold it
  /// (creation + explicit root, no early-release capability). `persist` moves
  /// the window-owned reference into the default scope, which is the surface's
  /// equivalent of the actor-side `makeNumber`.
  private static func defaultScopeHold<C: JSContext>(
    _ context: C,
    count: Int
  ) async -> UInt64 {
    return await context.withInstantContext { scope in
      let start = monotonicNanos()
      for index in 0..<count {
        _ = scope.persist(scope.makeNumber(Double(index & 0xFFFF)))
      }
      return monotonicNanos() - start
    }
  }

  // MARK: Resolve and registry lookup

  /// Per-sample: mint `resolveHandles` live bindings, measure four hot
  /// phases in one isolated body (witness direct, witness resolve, actor
  /// direct, actor resolve), then invalidate + settle and measure the two
  /// miss paths. The direct phases are "the view is already in hand": their
  /// only difference from a hit phase is the registry/claim/track work.
  private static func runResolve<C: JSContext>(
    name: String,
    virtualMachine: C.VirtualMachine,
    bootstrap: C,
    barrier: ExecutorBarrier,
    config: BenchConfig,
    reporter: Reporter
  ) async {
    let handleCount = config.resolveHandles
    let reps = config.resolveReps
    let ops = handleCount * reps
    let sampleCount = config.samples
    let warmup = config.warmup

    func sample() async -> ResolveSample {
      var contextBox: C? = await makeContext(
        virtualMachine, via: bootstrap)
      let handles = await mintHandles(contextBox!, count: handleCount)

      let hit = await measureHits(
        contextBox!, handles: handles, reps: reps)

      for handle in handles {
        _ = handle.invalidate()
      }

      await barrier.ping()

      let miss = await measureMisses(
        contextBox!, dead: handles, reps: reps)

      contextBox = nil
      await barrier.ping()
      return ResolveSample(hit: hit, miss: miss)
    }

    var witnessDirect: [Double] = []
    var witnessHit: [Double] = []
    var actorDirect: [Double] = []
    var actorHit: [Double] = []
    var witnessMiss: [Double] = []
    var actorMiss: [Double] = []
    var invalidateMiss: [Double] = []
    for sampleIndex in 0..<(warmup + sampleCount) {
      let result = await sample()
      guard sampleIndex >= warmup else { continue }
      witnessDirect.append(Double(result.hit.witnessDirect) / Double(ops))
      witnessHit.append(Double(result.hit.witnessHit) / Double(ops))
      actorDirect.append(Double(result.hit.actorDirect) / Double(ops))
      actorHit.append(Double(result.hit.actorHit) / Double(ops))
      witnessMiss.append(Double(result.miss.witnessMiss) / Double(ops))
      actorMiss.append(Double(result.miss.actorMiss) / Double(ops))
      invalidateMiss.append(
        Double(result.miss.invalidateMiss) / Double(ops))
      precondition(
        result.miss.misses == ops * 2,
        "dead-handle resolve unexpectedly succeeded")
      precondition(
        result.miss.discardedInvalidations == ops,
        "dead-handle invalidate unexpectedly killed a binding")
      precondition(result.hit.checksum.isFinite)
    }

    func stats(_ samples: [Double], _ metric: String) -> Stats {
      Stats(
        samples: samples,
        seed: stableSeed("\(name)/resolve/\(metric)"),
        resamples: config.bootstrapResamples)
    }

    reporter.add(
      engine: name, group: "resolve", metric: "direct default-scope read",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(witnessDirect, "direct-default"),
      note: "view already in hand; toNumber only")
    reporter.add(
      engine: name, group: "resolve", metric: "witness resolve (JSScope)",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(witnessHit, "witness-hit"),
      note: "box access + lookup + claim + track + toNumber")
    reporter.add(
      engine: name, group: "resolve", metric: "actor resolve (JSContext)",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(actorHit, "actor-hit"),
      note: "property access + lookup + claim + default-scope root + toNumber")
    reporter.add(
      engine: name, group: "resolve", metric: "direct read (actor phase)",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(actorDirect, "direct-actor"),
      note: "drift check; same loop as the witness direct baseline")
    reporter.add(
      engine: name, group: "registry lookup",
      metric: "resolve miss (witness)",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(witnessMiss, "witness-miss"),
      note: "box access + id/slot/generation checks")
    reporter.add(
      engine: name, group: "registry lookup",
      metric: "resolve miss (actor)",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(actorMiss, "actor-miss"),
      note: "direct property + id/slot/generation checks")
    reporter.add(
      engine: name, group: "registry lookup",
      metric: "invalidate miss",
      unit: "ns/op", opsPerSample: ops,
      stats: stats(invalidateMiss, "invalidate-miss"),
      note: "metadata only; no engine call")

    print(
      String(
        format:
          "  resolve overhead (witness hit - direct): %+.2f ns/op; "
          + "actor - witness: %+.2f ns/op; box (miss) overhead: %+.2f ns/op",
        stats(witnessHit, "witness-hit").median
          - stats(witnessDirect, "direct-default").median,
        stats(actorHit, "actor-hit").median
          - stats(witnessHit, "witness-hit").median,
        stats(witnessMiss, "witness-miss").median
          - stats(actorMiss, "actor-miss").median))
  }

  private static func measureHits<C: JSContext>(
    _ context: isolated C,
    handles: [C.PersistentHandle],
    reps: Int
  ) -> ResolveHitTimings {
    let scope = context.makeScope()
    // Default-scope value: the view is in hand for the whole measurement.
    let direct = context.makeNumber(7)
    let ops = reps * handles.count
    var checksum = 0.0

    let witnessDirectStart = monotonicNanos()
    for _ in 0..<ops {
      checksum += scope.driverContextHandle.toNumberForHandle(
        direct.borrowHandle())
    }
    let witnessDirect = monotonicNanos() - witnessDirectStart

    let witnessHitStart = monotonicNanos()
    for _ in 0..<reps {
      for handle in handles {
        if let value = scope.resolve(handle) {
          checksum += scope.driverContextHandle.toNumberForHandle(
            value.borrowHandle())
        }
      }
    }
    let witnessHit = monotonicNanos() - witnessHitStart

    let actorDirectStart = monotonicNanos()
    for _ in 0..<ops {
      checksum += scope.driverContextHandle.toNumberForHandle(
        direct.borrowHandle())
    }
    let actorDirect = monotonicNanos() - actorDirectStart

    let actorHitStart = monotonicNanos()
    for _ in 0..<reps {
      for handle in handles {
        if let value = context.resolve(handle) {
          checksum += scope.driverContextHandle.toNumberForHandle(
            value.borrowHandle())
        }
      }
    }
    let actorHit = monotonicNanos() - actorHitStart

    return ResolveHitTimings(
      witnessDirect: witnessDirect,
      witnessHit: witnessHit,
      actorDirect: actorDirect,
      actorHit: actorHit,
      checksum: checksum)
  }

  private static func measureMisses<C: JSContext>(
    _ context: isolated C,
    dead: [C.PersistentHandle],
    reps: Int
  ) -> ResolveMissTimings {
    let scope = context.makeScope()
    var misses = 0

    let witnessStart = monotonicNanos()
    for _ in 0..<reps {
      for handle in dead {
        if let value = scope.resolve(handle) {
          _ = value
        } else {
          misses += 1
        }
      }
    }
    let witnessMiss = monotonicNanos() - witnessStart

    let actorStart = monotonicNanos()
    for _ in 0..<reps {
      for handle in dead {
        if let value = context.resolve(handle) {
          _ = value
        } else {
          misses += 1
        }
      }
    }
    let actorMiss = monotonicNanos() - actorStart

    // Same thread and same op count as the two resolve-miss phases, so the
    // table of "lookup miss" numbers is directly comparable.
    var discardedInvalidations = 0
    let invalidateStart = monotonicNanos()
    for _ in 0..<reps {
      for handle in dead {
        if !handle.invalidate() {
          discardedInvalidations += 1
        }
      }
    }
    let invalidateMiss = monotonicNanos() - invalidateStart

    return ResolveMissTimings(
      witnessMiss: witnessMiss,
      actorMiss: actorMiss,
      invalidateMiss: invalidateMiss,
      misses: misses,
      discardedInvalidations: discardedInvalidations)
  }

  // MARK: Release

  private static func runRelease<C: JSContext>(
    name: String,
    virtualMachine: C.VirtualMachine,
    bootstrap: C,
    barrier: ExecutorBarrier,
    config: BenchConfig,
    reporter: Reporter
  ) async {
    let ops = config.releaseOps

    func invalidateSample() async -> UInt64 {
      var contextBox: C? = await makeContext(
        virtualMachine, via: bootstrap)
      let handles = await mintHandles(contextBox!, count: ops)
      let start = monotonicNanos()
      for handle in handles {
        _ = handle.invalidate()
      }
      await barrier.ping()
      let elapsed = monotonicNanos() - start
      contextBox = nil
      await barrier.ping()
      return elapsed
    }

    func deinitSample() async -> UInt64 {
      var contextBox: C? = await makeContext(
        virtualMachine, via: bootstrap)
      var handles: [C.PersistentHandle]? = await mintHandles(
        contextBox!, count: ops)
      let start = monotonicNanos()
      handles = nil
      await barrier.ping()
      let elapsed = monotonicNanos() - start
      contextBox = nil
      await barrier.ping()
      return elapsed
    }

    /// Default-scope settlement, measured as the per-value component of
    /// context teardown: (loaded - empty) / n.
    func defaultScopeSample() async -> UInt64 {
      var contextBox: C? = await makeContext(
        virtualMachine, via: bootstrap)
      _ = await defaultScopeHold(contextBox!, count: ops)
      let empty = await emptyTeardown(
        virtualMachine, bootstrap: bootstrap, barrier: barrier)
      let start = monotonicNanos()
      contextBox = nil
      await barrier.ping()
      let loaded = monotonicNanos() - start
      return positiveDifference(loaded, empty)
    }

    /// `close()` at container death, keeping the handles alive so the
    /// bindings are still `live` when the registry closes.
    func closeSample() async -> UInt64 {
      var contextBox: C? = await makeContext(
        virtualMachine, via: bootstrap)
      let handles = await mintHandles(contextBox!, count: ops)
      let empty = await emptyTeardown(
        virtualMachine, bootstrap: bootstrap, barrier: barrier)
      let start = monotonicNanos()
      contextBox = nil
      await barrier.ping()
      let loaded = monotonicNanos() - start
      withExtendedLifetime(handles) {}
      return positiveDifference(loaded, empty)
    }

    let invalidatePair = await measurePairedSeries(
      opsPerSample: ops, samples: config.samples, warmup: config.warmup,
      seed: stableSeed("\(name)/release/invalidate"),
      bootstrapResamples: config.bootstrapResamples,
      candidate: invalidateSample,
      baseline: defaultScopeSample
    )
    reporter.add(
      engine: name, group: "release", metric: "invalidate + settle",
      unit: "ns/op", opsPerSample: ops, stats: invalidatePair.candidate,
      note: "explicit invalidate loop + FIFO sentinel")
    reporter.add(
      engine: name, group: "release", metric: "default scope teardown",
      unit: "ns/op", opsPerSample: ops, stats: invalidatePair.baseline,
      note: "loaded - empty context teardown, per value")

    let deinitPair = await measurePairedSeries(
      opsPerSample: ops, samples: config.samples, warmup: config.warmup,
      seed: stableSeed("\(name)/release/deinit"),
      bootstrapResamples: config.bootstrapResamples,
      candidate: deinitSample,
      baseline: defaultScopeSample
    )
    reporter.add(
      engine: name, group: "release", metric: "last-owner deinit + settle",
      unit: "ns/op", opsPerSample: ops, stats: deinitPair.candidate,
      note: "drop handle array + FIFO sentinel")
    reporter.add(
      engine: name, group: "release", metric: "default scope teardown (2)",
      unit: "ns/op", opsPerSample: ops, stats: deinitPair.baseline,
      note: "paired repeat of the baseline")

    let closePair = await measurePairedSeries(
      opsPerSample: ops, samples: config.samples, warmup: config.warmup,
      seed: stableSeed("\(name)/release/close"),
      bootstrapResamples: config.bootstrapResamples,
      candidate: closeSample,
      baseline: defaultScopeSample
    )
    reporter.add(
      engine: name, group: "release", metric: "registry close at death",
      unit: "ns/op", opsPerSample: ops, stats: closePair.candidate,
      note: "live bindings settled inline by isolated deinit")
    reporter.add(
      engine: name, group: "release", metric: "default scope teardown (3)",
      unit: "ns/op", opsPerSample: ops, stats: closePair.baseline,
      note: "paired repeat of the baseline")

    print(
      String(
        format:
          "  release deltas vs default-scope teardown: "
          + "invalidate %+.2f, deinit %+.2f, close %+.2f ns/op",
        invalidatePair.candidate.median - invalidatePair.baseline.median,
        deinitPair.candidate.median - deinitPair.baseline.median,
        closePair.candidate.median - closePair.baseline.median))
  }

  // MARK: Mass invalidation scaling

  private static func runScale<C: JSContext>(
    name: String,
    virtualMachine: C.VirtualMachine,
    bootstrap: C,
    barrier: ExecutorBarrier,
    config: BenchConfig,
    reporter: Reporter
  ) async {
    for ops in config.scaleOps {
      func invalidateSample() async -> UInt64 {
        var contextBox: C? = await makeContext(
          virtualMachine, via: bootstrap)
        let handles = await mintHandles(contextBox!, count: ops)
        let start = monotonicNanos()
        for handle in handles {
          _ = handle.invalidate()
        }
        await barrier.ping()
        let elapsed = monotonicNanos() - start
        contextBox = nil
        await barrier.ping()
        return elapsed
      }

      func closeSample() async -> UInt64 {
        var contextBox: C? = await makeContext(
          virtualMachine, via: bootstrap)
        let handles = await mintHandles(contextBox!, count: ops)
        let empty = await emptyTeardown(
          virtualMachine, bootstrap: bootstrap, barrier: barrier)
        let start = monotonicNanos()
        contextBox = nil
        await barrier.ping()
        let loaded = monotonicNanos() - start
        withExtendedLifetime(handles) {}
        return positiveDifference(loaded, empty)
      }

      func defaultScopeSample() async -> UInt64 {
        var contextBox: C? = await makeContext(
          virtualMachine, via: bootstrap)
        _ = await defaultScopeHold(contextBox!, count: ops)
        let empty = await emptyTeardown(
          virtualMachine, bootstrap: bootstrap, barrier: barrier)
        let start = monotonicNanos()
        contextBox = nil
        await barrier.ping()
        let loaded = monotonicNanos() - start
        return positiveDifference(loaded, empty)
      }

      let invalidatePair = await measurePairedSeries(
        opsPerSample: ops, samples: config.scaleSamples, warmup: 1,
        seed: stableSeed("\(name)/scale/invalidate/\(ops)"),
        bootstrapResamples: config.bootstrapResamples,
        candidate: invalidateSample,
        baseline: defaultScopeSample
      )
      reporter.add(
        engine: name, group: "mass invalidation",
        metric: "invalidate + settle n=\(ops)",
        unit: "ns/op", opsPerSample: ops, stats: invalidatePair.candidate,
        note: "total: \(milliseconds(invalidatePair.candidate.median * Double(ops))) ms")
      reporter.add(
        engine: name, group: "mass invalidation",
        metric: "default scope teardown n=\(ops)",
        unit: "ns/op", opsPerSample: ops, stats: invalidatePair.baseline,
        note: "total: \(milliseconds(invalidatePair.baseline.median * Double(ops))) ms")

      let closePair = await measurePairedSeries(
        opsPerSample: ops, samples: config.scaleSamples, warmup: 1,
        seed: stableSeed("\(name)/scale/close/\(ops)"),
        bootstrapResamples: config.bootstrapResamples,
        candidate: closeSample,
        baseline: defaultScopeSample
      )
      reporter.add(
        engine: name, group: "mass invalidation",
        metric: "registry close n=\(ops)",
        unit: "ns/op", opsPerSample: ops, stats: closePair.candidate,
        note: "total: \(milliseconds(closePair.candidate.median * Double(ops))) ms")
      reporter.add(
        engine: name, group: "mass invalidation",
        metric: "default scope teardown n=\(ops) (2)",
        unit: "ns/op", opsPerSample: ops, stats: closePair.baseline,
        note: "total: \(milliseconds(closePair.baseline.median * Double(ops))) ms")
    }
  }

  // MARK: Teardown helpers

  /// Empty-context teardown baseline. The FIFO sentinel is included in both
  /// the empty and the loaded measurement and therefore cancels in the
  /// per-value difference.
  private static func emptyTeardown<C: JSContext>(
    _ virtualMachine: C.VirtualMachine,
    bootstrap: C,
    barrier: ExecutorBarrier
  ) async -> UInt64 {
    var contextBox: C? = await makeContext(
      virtualMachine, via: bootstrap)
    let start = monotonicNanos()
    contextBox = nil
    await barrier.ping()
    return monotonicNanos() - start
  }

  private static func positiveDifference(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
    lhs >= rhs ? lhs - rhs : 0
  }

  private static func milliseconds(_ nanos: Double) -> String {
    String(format: "%.3f", nanos / 1_000_000)
  }
}
