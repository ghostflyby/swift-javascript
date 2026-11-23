import Foundation
import Synchronization

// MARK: - Table prototypes
//
// These prototypes isolate the **metadata** cost of the persistent-binding
// table: no engine calls, no Swift class per binding (unless a prototype
// deliberately models one), payloads are plain `UInt64`. They are the
// calibration half of the benchmark; the end-to-end half runs through the
// real `JSPersistentHandleRegistry` in `BenchmarkMain.swift`.
//
// The slot prototype mirrors the registry's documented algorithm (chunked
// slabs, per-slot generation, free list). The dictionary prototypes model the
// alternatives: monotonic tokens (never reused) and reused slots with a boxed
// entry (the shape a `~Copyable` engine handle forces on `Dictionary`).

protocol SyntheticValueTable: AnyObject, Sendable {
  associatedtype Token: Sendable

  func mint(_ payload: UInt64) -> Token
  func lookup(_ token: Token) -> UInt64?
  func release(_ token: Token) -> UInt64?
  func tokenChecksum(_ token: Token) -> UInt64
}

struct SyntheticSlotToken: Sendable {
  let slot: UInt32
  let generation: UInt32
}

/// Chunked slab with generation and free list, matching
/// `JSPersistentHandleRegistry`'s allocation/lookup/release metadata.
final class SyntheticSlotTable: SyntheticValueTable, @unchecked Sendable {
  final class Chunk {
    let capacity: Int
    var payloads: [UInt64]
    var generations: [UInt32]
    var live: [Bool]

    init(capacity: Int) {
      self.capacity = capacity
      self.payloads = Array(repeating: 0, count: capacity)
      self.generations = Array(repeating: 0, count: capacity)
      self.live = Array(repeating: false, count: capacity)
    }
  }

  struct State {
    var chunks: [Chunk] = []
    var freeList: [UInt32] = []
    var nextFresh: UInt32 = 0
  }

  let capacity: Int
  /// Shift/mask rather than `/` and `%`: the real registry's chunk capacity
  /// is a compile-time constant, so the optimizer sees shifts there. A
  /// stored `let capacity` would leave a runtime division in this prototype
  /// and make the slot table look artificially slower than it is.
  private let chunkShift: UInt32
  private let chunkMask: UInt32
  private let state = Mutex(State())

  init(capacity: Int) {
    precondition(
      capacity > 0 && capacity.nonzeroBitCount == 1,
      "synthetic slot capacity must be a power of two")
    self.capacity = capacity
    self.chunkShift = UInt32(capacity.trailingZeroBitCount)
    self.chunkMask = UInt32(capacity - 1)
  }

  func mint(_ payload: UInt64) -> SyntheticSlotToken {
    state.withLock { state in
      let slot: UInt32
      let chunk: Chunk
      let index: Int
      let generation: UInt32

      if let reused = state.freeList.popLast() {
        slot = reused
        let chunkIndex = Int(reused >> chunkShift)
        chunk = state.chunks[chunkIndex]
        index = Int(reused & chunkMask)
        generation = chunk.generations[index] + 1
        chunk.generations[index] = generation
        chunk.live[index] = true
      } else {
        slot = state.nextFresh
        state.nextFresh += 1
        let chunkIndex = Int(slot >> chunkShift)
        if chunkIndex == state.chunks.count {
          state.chunks.append(Chunk(capacity: capacity))
        }
        chunk = state.chunks[chunkIndex]
        index = Int(slot & chunkMask)
        generation = 1
        chunk.generations[index] = 1
        chunk.live[index] = true
      }
      chunk.payloads[index] = payload
      return SyntheticSlotToken(slot: slot, generation: generation)
    }
  }

  func lookup(_ token: SyntheticSlotToken) -> UInt64? {
    state.withLock { state in
      let chunkIndex = Int(token.slot >> chunkShift)
      guard chunkIndex < state.chunks.count else { return nil }
      let chunk = state.chunks[chunkIndex]
      let index = Int(token.slot & chunkMask)
      guard chunk.generations[index] == token.generation,
        chunk.live[index]
      else { return nil }
      return chunk.payloads[index]
    }
  }

  func release(_ token: SyntheticSlotToken) -> UInt64? {
    state.withLock { state in
      let chunkIndex = Int(token.slot >> chunkShift)
      guard chunkIndex < state.chunks.count else { return nil }
      let chunk = state.chunks[chunkIndex]
      let index = Int(token.slot & chunkMask)
      guard chunk.generations[index] == token.generation,
        chunk.live[index]
      else { return nil }
      chunk.generations[index] += 1
      chunk.live[index] = false
      state.freeList.append(token.slot)
      return chunk.payloads[index]
    }
  }

  func tokenChecksum(_ token: SyntheticSlotToken) -> UInt64 {
    UInt64(token.slot) &+ UInt64(token.generation)
  }
}

/// Dictionary keyed by a monotonically increasing token. This is the
/// "simplest dictionary registry": honest O(1) hash lookup, no reuse, no
/// generation check, but token space and table size grow with cumulative
/// mints rather than with peak concurrency.
final class SyntheticDictMonotonicTable: SyntheticValueTable, @unchecked Sendable {
  struct State {
    var entries: [UInt64: UInt64] = [:]
    var nextToken: UInt64 = 0
  }

  private let state = Mutex(State())

  func mint(_ payload: UInt64) -> UInt64 {
    state.withLock { state in
      let token = state.nextToken
      state.nextToken += 1
      state.entries[token] = payload
      return token
    }
  }

  func lookup(_ token: UInt64) -> UInt64? {
    state.withLock { $0.entries[token] }
  }

  func release(_ token: UInt64) -> UInt64? {
    state.withLock { $0.entries.removeValue(forKey: token) }
  }

  func tokenChecksum(_ token: UInt64) -> UInt64 {
    token
  }
}

/// Dictionary with reused slot keys and generation-checked boxed entries.
///
/// This is the fair alternative for a `~Copyable` payload: `Dictionary`'s
/// elements must be `Copyable`, so each entry needs a heap box. The box is
/// also where the generation lives, mirroring the slot table's per-slot
/// generation array.
final class SyntheticDictBoxedTable: SyntheticValueTable, @unchecked Sendable {
  final class EntryBox {
    let generation: UInt32
    let payload: UInt64

    init(generation: UInt32, payload: UInt64) {
      self.generation = generation
      self.payload = payload
    }
  }

  struct State {
    var entries: [UInt32: EntryBox] = [:]
    var generations: [UInt32] = []
    var freeList: [UInt32] = []
    var nextFresh: UInt32 = 0
  }

  private let state = Mutex(State())

  func mint(_ payload: UInt64) -> SyntheticSlotToken {
    state.withLock { state in
      let slot: UInt32
      let generation: UInt32
      if let reused = state.freeList.popLast() {
        slot = reused
        generation = state.generations[Int(reused)] + 1
      } else {
        slot = state.nextFresh
        state.nextFresh += 1
        state.generations.append(0)
        generation = 1
      }
      state.generations[Int(slot)] = generation
      state.entries[slot] = EntryBox(generation: generation, payload: payload)
      return SyntheticSlotToken(slot: slot, generation: generation)
    }
  }

  func lookup(_ token: SyntheticSlotToken) -> UInt64? {
    state.withLock { state in
      guard let box = state.entries[token.slot],
        box.generation == token.generation
      else { return nil }
      return box.payload
    }
  }

  func release(_ token: SyntheticSlotToken) -> UInt64? {
    state.withLock { state in
      guard let box = state.entries[token.slot],
        box.generation == token.generation
      else { return nil }
      state.entries.removeValue(forKey: token.slot)
      state.generations[Int(token.slot)] += 1
      state.freeList.append(token.slot)
      return box.payload
    }
  }

  func tokenChecksum(_ token: SyntheticSlotToken) -> UInt64 {
    UInt64(token.slot) &+ UInt64(token.generation)
  }
}

// MARK: - Drain kernels
//
// `@inline(never)` and an opaque fill are deliberate: a loop over a freshly
// created `0..<n` array was observed to be constant-folded to ~0.01 ns/op,
// which would have hidden the whole point of the comparison.

@inline(never)
private func drainRemoveFirst(_ pending: inout [UInt32]) -> UInt64 {
  var checksum: UInt64 = 0
  while !pending.isEmpty {
    checksum &+= UInt64(pending.removeFirst())
  }
  return checksum
}

@inline(never)
private func drainHeadCursor(_ pending: [UInt32]) -> UInt64 {
  var checksum: UInt64 = 0
  var head = 0
  while head < pending.count {
    checksum &+= UInt64(pending[head])
    head += 1
  }
  return checksum
}

// MARK: - Workloads

enum SyntheticBenchmarks {
  static func run(config: BenchConfig, reporter: Reporter) async {
    print("\n# synthetic metadata prototypes (no engine calls)")
    let seedBase = "synthetic"

    for capacity in [32, 64, 128] {
      measureTable(
        make: { SyntheticSlotTable(capacity: capacity) },
        name: "slot-\(capacity)",
        config: config,
        reporter: reporter,
        seedBase: seedBase
      )
    }
    measureTable(
      make: { SyntheticDictMonotonicTable() },
      name: "dict-monotonic",
      config: config,
      reporter: reporter,
      seedBase: seedBase
    )
    measureTable(
      make: { SyntheticDictBoxedTable() },
      name: "dict-reuse-boxed",
      config: config,
      reporter: reporter,
      seedBase: seedBase
    )

    measurePendingDrain(config: config, reporter: reporter, seedBase: seedBase)

    await measureContendedLookups(
      config: config, reporter: reporter, seedBase: seedBase)
  }

  private static func measureTable<T: SyntheticValueTable>(
    make: @escaping () -> T,
    name: String,
    config: BenchConfig,
    reporter: Reporter,
    seedBase: String
  ) {
    let ops = config.syntheticOps
    let samples = config.syntheticSamples
    let warmup = config.syntheticWarmup
    let resamples = config.bootstrapResamples
    var sink: UInt64 = 0

    let insert = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: warmup,
      seed: stableSeed("\(seedBase)/\(name)/insert"),
      bootstrapResamples: resamples
    ) {
      let table = make()
      let start = monotonicNanos()
      for index in 0..<ops {
        sink &+= table.tokenChecksum(table.mint(UInt64(index)))
      }
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: name, metric: "insert",
      unit: "ns/op", opsPerSample: ops, stats: insert)

    let hit = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: warmup,
      seed: stableSeed("\(seedBase)/\(name)/lookup-hit"),
      bootstrapResamples: resamples
    ) {
      let table = make()
      var tokens: [T.Token] = []
      tokens.reserveCapacity(ops)
      for index in 0..<ops {
        tokens.append(table.mint(UInt64(index)))
      }
      let start = monotonicNanos()
      for token in tokens {
        sink &+= table.lookup(token) ?? 0
      }
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: name, metric: "lookup hit",
      unit: "ns/op", opsPerSample: ops, stats: hit)

    let miss = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: warmup,
      seed: stableSeed("\(seedBase)/\(name)/lookup-miss"),
      bootstrapResamples: resamples
    ) {
      let table = make()
      var tokens: [T.Token] = []
      tokens.reserveCapacity(ops)
      for index in 0..<ops {
        tokens.append(table.mint(UInt64(index)))
      }
      for token in tokens {
        sink &+= table.release(token) ?? 0
      }
      let start = monotonicNanos()
      for token in tokens {
        sink &+= table.lookup(token) ?? 0
      }
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: name, metric: "lookup miss",
      unit: "ns/op", opsPerSample: ops, stats: miss)

    let release = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: warmup,
      seed: stableSeed("\(seedBase)/\(name)/release"),
      bootstrapResamples: resamples
    ) {
      let table = make()
      var tokens: [T.Token] = []
      tokens.reserveCapacity(ops)
      for index in 0..<ops {
        tokens.append(table.mint(UInt64(index)))
      }
      let start = monotonicNanos()
      for token in tokens {
        sink &+= table.release(token) ?? 0
      }
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: name, metric: "release",
      unit: "ns/op", opsPerSample: ops, stats: release)

    let churn = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: warmup,
      seed: stableSeed("\(seedBase)/\(name)/churn"),
      bootstrapResamples: resamples
    ) {
      let table = make()
      let start = monotonicNanos()
      for index in 0..<ops {
        let token = table.mint(UInt64(index))
        sink &+= table.tokenChecksum(token)
        sink &+= table.release(token) ?? 0
      }
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: name, metric: "mint+release",
      unit: "ns/op", opsPerSample: ops, stats: churn,
      note: "one mint/release pair per op")

    withExtendedLifetime(sink) {}
  }

  /// The registry's pump currently removes the head of an `Array` pending
  /// queue (`removeFirst`), which shifts every remaining element. This
  /// microbenchmark measures that shape against a head-index drain so the
  /// quadratic cost is visible rather than inferred.
  private static func measurePendingDrain(
    config: BenchConfig,
    reporter: Reporter,
    seedBase: String
  ) {
    let ops = config.syntheticOps
    let samples = config.syntheticSamples
    let resamples = config.bootstrapResamples
    var sink: UInt64 = 0

    let removeFirst = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: config.syntheticWarmup,
      seed: stableSeed("\(seedBase)/pending/removeFirst"),
      bootstrapResamples: resamples
    ) {
      let base = monotonicNanos()
      var pending = (0..<ops).map {
        UInt32(truncatingIfNeeded: base &+ UInt64($0))
      }
      let start = monotonicNanos()
      sink &+= drainRemoveFirst(&pending)
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: "pending queue", metric: "drain removeFirst",
      unit: "ns/op", opsPerSample: ops, stats: removeFirst,
      note: "Array.removeFirst, O(n^2) total")

    let cursor = measureSyncSeries(
      opsPerSample: ops, samples: samples, warmup: config.syntheticWarmup,
      seed: stableSeed("\(seedBase)/pending/cursor"),
      bootstrapResamples: resamples
    ) {
      let base = monotonicNanos()
      let pending = (0..<ops).map {
        UInt32(truncatingIfNeeded: base &+ UInt64($0))
      }
      let start = monotonicNanos()
      sink &+= drainHeadCursor(pending)
      return monotonicNanos() - start
    }
    reporter.add(
      engine: "synthetic", group: "pending queue", metric: "drain head cursor",
      unit: "ns/op", opsPerSample: ops, stats: cursor,
      note: "O(n) total")

    withExtendedLifetime(sink) {}
  }

  /// Contended hit lookups: four cooperative tasks hammer one table through
  /// its single mutex. This is a proxy for cross-thread `invalidate` traffic
  /// against VM-thread resolution, not a simulation of the real registry
  /// (which cannot be resolved off the VM thread).
  private static func measureContendedLookups(
    config: BenchConfig,
    reporter: Reporter,
    seedBase: String
  ) async {
    let threads = 4
    let tokensPerThread = 256
    let perThreadOps = 10_000
    let samples = config.quickLikeSamplesForContention
    let resamples = config.bootstrapResamples

    func measure<T: SyntheticValueTable>(_ make: @escaping () -> T) async -> Stats {
      // Each task performs `perThreadOps * tokensPerThread` lookups.
      let aggregateOps = threads * perThreadOps * tokensPerThread
      var perOp: [Double] = []
      perOp.reserveCapacity(samples)
      for _ in 0..<samples {
        let table = make()
        var builtTokens: [T.Token] = []
        builtTokens.reserveCapacity(tokensPerThread)
        for index in 0..<tokensPerThread {
          builtTokens.append(table.mint(UInt64(index)))
        }
        // `let` snapshot: the task closure is `sending`, so it must not
        // capture the mutable setup buffer.
        let tokens = builtTokens
        let start = monotonicNanos()
        let checksum = await withTaskGroup(of: UInt64.self) { group in
          for _ in 0..<threads {
            group.addTask {
              var sum: UInt64 = 0
              for _ in 0..<perThreadOps {
                for token in tokens {
                  sum &+= table.lookup(token) ?? 0
                }
              }
              return sum
            }
          }
          var total: UInt64 = 0
          for await value in group {
            total &+= value
          }
          return total
        }
        let elapsed = monotonicNanos() - start
        withExtendedLifetime(checksum) {}
        perOp.append(Double(elapsed) / Double(aggregateOps))
      }
      return Stats(
        samples: perOp,
        seed: stableSeed("\(seedBase)/contended"),
        resamples: resamples)
    }

    let aggregateOps = threads * perThreadOps * tokensPerThread
    let slot = await measure { SyntheticSlotTable(capacity: 32) }
    reporter.add(
      engine: "synthetic", group: "contended lookup (4 tasks)",
      metric: "slot-32", unit: "ns/op",
      opsPerSample: aggregateOps, stats: slot)
    let dict = await measure { SyntheticDictMonotonicTable() }
    reporter.add(
      engine: "synthetic", group: "contended lookup (4 tasks)",
      metric: "dict-monotonic", unit: "ns/op",
      opsPerSample: aggregateOps, stats: dict)
  }
}

extension BenchConfig {
  fileprivate var quickLikeSamplesForContention: Int {
    max(3, samples / 3)
  }
}
