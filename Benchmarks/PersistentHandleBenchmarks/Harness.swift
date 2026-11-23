import Darwin
import Foundation

// MARK: - Clock

/// Monotonic wall-clock nanoseconds. `CLOCK_UPTIME_RAW` on Darwin does not
/// advance while the machine is asleep and has no civil-time adjustments.
@inline(__always)
func monotonicNanos() -> UInt64 {
  clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
}

// MARK: - Deterministic resampling

/// SplitMix64: small, seedable, and adequate for bootstrap resampling. Using
/// a deterministic stream keeps a published confidence interval reproducible
/// from the same samples.
struct SplitMix64: RandomNumberGenerator {
  var state: UInt64

  init(state: UInt64) {
    self.state = state
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

func stableSeed(_ text: String) -> UInt64 {
  var hash: UInt64 = 0xcbf2_9ce4_8422_2325
  for byte in text.utf8 {
    hash ^= UInt64(byte)
    hash &*= 0x0000_0100_0000_01B3
  }
  return hash
}

// MARK: - Statistics

/// Linear-interpolated quantile over a sorted sample.
func quantile(_ sorted: [Double], _ probability: Double) -> Double {
  precondition(!sorted.isEmpty)
  if sorted.count == 1 { return sorted[0] }
  let position = probability * Double(sorted.count - 1)
  let lower = Int(position.rounded(.down))
  let upper = Swift.min(lower + 1, sorted.count - 1)
  let fraction = position - Double(lower)
  return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
}

/// Descriptive statistics plus a percentile-bootstrap 95% CI of the median.
///
/// The CI describes **run-to-run variation of this machine under its current
/// load**; it is not a claim about another host. Wide intervals are reported
/// as-is rather than hidden behind a point estimate.
struct Stats: Sendable {
  let samples: [Double]
  let median: Double
  let ciLow: Double
  let ciHigh: Double
  let mean: Double
  let standardDeviation: Double
  let minValue: Double
  let maxValue: Double
  let p10: Double
  let p90: Double

  var count: Int { samples.count }
  var coefficientOfVariation: Double {
    mean == 0 ? 0 : standardDeviation / mean
  }

  init(samples: [Double], seed: UInt64, resamples: Int = 2_000) {
    precondition(!samples.isEmpty, "Stats needs at least one sample")
    self.samples = samples
    let sorted = samples.sorted()
    self.median = quantile(sorted, 0.5)
    self.minValue = sorted.first!
    self.maxValue = sorted.last!
    self.p10 = quantile(sorted, 0.10)
    self.p90 = quantile(sorted, 0.90)

    let mean = samples.reduce(0, +) / Double(samples.count)
    self.mean = mean
    if samples.count > 1 {
      let variance =
        samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        / Double(samples.count)
      self.standardDeviation = variance.squareRoot()
    } else {
      self.standardDeviation = 0
    }

    var rng = SplitMix64(state: seed)
    var bootstrapMedians: [Double] = []
    bootstrapMedians.reserveCapacity(resamples)
    let n = samples.count
    for _ in 0..<resamples {
      var drawn: [Double] = []
      drawn.reserveCapacity(n)
      for _ in 0..<n {
        drawn.append(samples[Int(rng.next() % UInt64(n))])
      }
      drawn.sort()
      bootstrapMedians.append(quantile(drawn, 0.5))
    }
    bootstrapMedians.sort()
    self.ciLow = quantile(bootstrapMedians, 0.025)
    self.ciHigh = quantile(bootstrapMedians, 0.975)
  }
}

// MARK: - Configuration

enum BenchDebug {
  static let enabled = ProcessInfo.processInfo.environment["BENCH_DEBUG"] != nil
}

struct BenchConfig: Sendable {
  var samples: Int
  var warmup: Int
  var allocationOps: Int
  var resolveHandles: Int
  var resolveReps: Int
  var releaseOps: Int
  var scaleOps: [Int]
  var scaleSamples: Int
  var syntheticOps: Int
  var syntheticSamples: Int
  var syntheticWarmup: Int
  var bootstrapResamples: Int

  static let standard = BenchConfig(
    samples: 17,
    warmup: 2,
    allocationOps: 16_384,
    resolveHandles: 2_048,
    resolveReps: 64,
    releaseOps: 16_384,
    scaleOps: [1_024, 8_192, 65_536],
    scaleSamples: 7,
    syntheticOps: 32_768,
    syntheticSamples: 13,
    syntheticWarmup: 1,
    bootstrapResamples: 4_000
  )

  /// A reduced run for developing the harness; not used for published data.
  static let quick = BenchConfig(
    samples: 5,
    warmup: 1,
    allocationOps: 2_048,
    resolveHandles: 256,
    resolveReps: 8,
    releaseOps: 2_048,
    scaleOps: [512, 2_048],
    scaleSamples: 3,
    syntheticOps: 4_096,
    syntheticSamples: 5,
    syntheticWarmup: 1,
    bootstrapResamples: 1_000
  )
}

// MARK: - Measurements

struct Measurement: Sendable {
  let engine: String
  let group: String
  let metric: String
  let unit: String
  let opsPerSample: Int
  let stats: Stats
  let note: String

  var medianPerOp: Double {
    unit == "ns/op" ? stats.median : stats.median / Double(opsPerSample)
  }
}

final class Reporter {
  private(set) var measurements: [Measurement] = []
  private var order: [(engine: String, group: String)] = []

  func add(
    engine: String,
    group: String,
    metric: String,
    unit: String,
    opsPerSample: Int,
    stats: Stats,
    note: String = ""
  ) {
    let measurement = Measurement(
      engine: engine,
      group: group,
      metric: metric,
      unit: unit,
      opsPerSample: opsPerSample,
      stats: stats,
      note: note
    )
    measurements.append(measurement)
    if !order.contains(where: { $0.engine == engine && $0.group == group }) {
      order.append((engine, group))
    }

    let median = stats.median
    let low = stats.ciLow
    let high = stats.ciHigh
    let cv = stats.coefficientOfVariation * 100
    let engineColumn = engine.padding(toLength: 14, withPad: " ", startingAt: 0)
    let groupColumn = group.padding(toLength: 22, withPad: " ", startingAt: 0)
    let metricColumn = metric.padding(toLength: 44, withPad: " ", startingAt: 0)
    let unitColumn = unit.padding(toLength: 10, withPad: " ", startingAt: 0)
    print(
      engineColumn + " " + groupColumn + " " + metricColumn + " " + unitColumn
        + String(
          format: "%12.2f [%10.2f, %10.2f]  cv=%5.1f%%  n=%d",
          median, low, high, cv, stats.count))
  }

  func printMarkdown() {
    print("\n<!-- BEGIN GENERATED MARKDOWN -->")
    for key in order {
      print("\n#### \(key.engine) / \(key.group)\n")
      print("| metric | ops/sample | median | 95% CI | mean ± sd | CV | p10 / p90 |")
      print("|---|---:|---:|---:|---:|---:|---:|")
      for measurement in measurements
      where measurement.engine == key.engine && measurement.group == key.group {
        let stats = measurement.stats
        let ops = measurement.opsPerSample
        print(
          "| \(measurement.metric) | \(ops) | "
            + String(format: "%.2f", stats.median)
            + " \(measurement.unit) | ["
            + String(format: "%.2f", stats.ciLow) + ", "
            + String(format: "%.2f", stats.ciHigh) + "] | "
            + String(format: "%.2f", stats.mean) + " ± "
            + String(format: "%.2f", stats.standardDeviation) + " | "
            + String(format: "%.1f%%", stats.coefficientOfVariation * 100)
            + " | "
            + String(format: "%.2f", stats.p10) + " / "
            + String(format: "%.2f", stats.p90) + " |")
      }
    }
    print("<!-- END GENERATED MARKDOWN -->")
  }
}

// MARK: - Environment

func sysctlString(_ name: String) -> String {
  var size = 0
  guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
    return "unknown"
  }
  var buffer = [CChar](repeating: 0, count: size)
  guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
    return "unknown"
  }
  return String(cString: buffer)
}

func printEnvironment(config: BenchConfig) {
  var load = [Double](repeating: 0, count: 3)
  _ = getloadavg(&load, 3)
  let memoryGiB =
    Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
  var build = "release"
  #if DEBUG
    build = "debug"
  #endif
  print("# Persistent-handle Stage 4 benchmark")
  print(
    "# host: \(sysctlString("machdep.cpu.brand_string")), "
      + "\(ProcessInfo.processInfo.processorCount) logical cores, "
      + String(format: "%.0f GiB RAM", memoryGiB))
  print(
    "# os: \(ProcessInfo.processInfo.operatingSystemVersionString); "
      + "build: \(build)")
  print(
    String(
      format: "# load average (1/5/15m) at start: %.2f %.2f %.2f",
      load[0], load[1], load[2]))
  print(
    "# config: samples=\(config.samples) warmup=\(config.warmup) "
      + "alloc=\(config.allocationOps) resolve=\(config.resolveHandles)x\(config.resolveReps) "
      + "release=\(config.releaseOps) scale=\(config.scaleOps)x\(config.scaleSamples) "
      + "synthetic=\(config.syntheticOps)x\(config.syntheticSamples)")
  print("")
}

// MARK: - Timing helpers

/// Run `body` once per sample; `body` returns the elapsed nanoseconds for a
/// batch of `opsPerSample` operations. Warmup samples are discarded.
func measureSeries(
  opsPerSample: Int,
  samples: Int,
  warmup: Int,
  seed: UInt64,
  bootstrapResamples: Int,
  _ body: () async -> UInt64
) async -> Stats {
  for _ in 0..<warmup {
    _ = await body()
  }
  var perOp: [Double] = []
  perOp.reserveCapacity(samples)
  for _ in 0..<samples {
    let nanos = await body()
    perOp.append(Double(nanos) / Double(opsPerSample))
  }
  return Stats(samples: perOp, seed: seed, resamples: bootstrapResamples)
}

/// Paired variant: both sides run in the same sample slot, alternating order
/// to cancel slow monotonic drift (thermal, allocator). The reported series
/// stay independent; pairing only improves the conditions of each pair.
func measurePairedSeries(
  opsPerSample: Int,
  samples: Int,
  warmup: Int,
  seed: UInt64,
  bootstrapResamples: Int,
  candidate: () async -> UInt64,
  baseline: () async -> UInt64
) async -> (candidate: Stats, baseline: Stats) {
  for _ in 0..<warmup {
    _ = await candidate()
    _ = await baseline()
  }
  var candidateSamples: [Double] = []
  var baselineSamples: [Double] = []
  candidateSamples.reserveCapacity(samples)
  baselineSamples.reserveCapacity(samples)
  for index in 0..<samples {
    let candidateNanos: UInt64
    let baselineNanos: UInt64
    if index % 2 == 0 {
      candidateNanos = await candidate()
      baselineNanos = await baseline()
    } else {
      baselineNanos = await baseline()
      candidateNanos = await candidate()
    }
    candidateSamples.append(Double(candidateNanos) / Double(opsPerSample))
    baselineSamples.append(Double(baselineNanos) / Double(opsPerSample))
  }
  return (
    Stats(
      samples: candidateSamples, seed: seed,
      resamples: bootstrapResamples),
    Stats(
      samples: baselineSamples, seed: seed ^ 0xA5A5_5A5A_0F0F_F0F0,
      resamples: bootstrapResamples)
  )
}

/// Synchronous counterpart for the engine-independent table prototypes.
func measureSyncSeries(
  opsPerSample: Int,
  samples: Int,
  warmup: Int,
  seed: UInt64,
  bootstrapResamples: Int,
  _ body: () -> UInt64
) -> Stats {
  for _ in 0..<warmup {
    _ = body()
  }
  var perOp: [Double] = []
  perOp.reserveCapacity(samples)
  for _ in 0..<samples {
    perOp.append(Double(body()) / Double(opsPerSample))
  }
  return Stats(samples: perOp, seed: seed, resamples: bootstrapResamples)
}
