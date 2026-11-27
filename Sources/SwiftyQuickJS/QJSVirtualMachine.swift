import Dispatch
import SwiftJavaScript
import Synchronization
import ThreadAffinityExecutor

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// The QuickJS virtual machine: one runtime plus the executor every context of
/// this VM runs on.
///
/// Engine state is created during `init`, on the VM's executor, and released by
/// `isolated deinit` on that same executor. `init` blocks until the runtime
/// exists; the `JSInitMode.nonblocking` form awaits instead. A caller that
/// already is on the executor runs the initialization inline.
///
/// QuickJS's stack bookkeeping needs a known current OS thread, so this VM
/// accepts any `ThreadAffinityExecutor`: a thread-bound executor keeps one OS
/// thread for the VM's lifetime, and a `MigratingThreadExecutor` switches
/// threads only through an explicit migration whose entering-bound-thread
/// notification refreshes the runtime's recorded stack top.
public actor QJSVirtualMachine: SwiftJavaScript.JSVirtualMachine {
  public typealias Context = QJSContext

  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// The executor every context of this VM runs on. Package-internal so a
  /// context's initializer can hop onto it.
  package nonisolated let executor: any ThreadAffinityExecutor

  /// The dedicated thread this VM created; nil when the executor is
  /// caller-supplied, whose lifetime belongs to the embedder.
  private let ownedExecutor: DedicatedThreadExecutor?

  /// The migration source when the executor is a `MigratingThreadExecutor`.
  private let migratingExecutor: MigratingThreadExecutor?

  /// The runtime's bit pattern, created during init (0 until then).
  private nonisolated let runtimeBox = Mutex<UInt>(0)

  /// The stack-top refresh registered on a migrating executor.
  private nonisolated(unsafe) var migrationHook: MigrationHookToken?

  /// Counts thread hand-offs the runtime has refreshed its stack top for.
  /// Package-internal: lets tests observe that the migration notification ran.
  private nonisolated let migrationRefreshes = MigrationRefreshCounter()

  public init() {
    let executor = DedicatedThreadExecutor()
    self.executor = executor
    self.ownedExecutor = executor
    self.migratingExecutor = nil
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    openRuntimeSynchronously()
  }

  public init(_ mode: JSInitMode) async {
    let executor = DedicatedThreadExecutor()
    self.executor = executor
    self.ownedExecutor = executor
    self.migratingExecutor = nil
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    await openRuntime()
  }

  /// Run every context of this VM on a caller-supplied thread-affinity
  /// executor. The executor is borrowed — this VM neither stops it nor waits
  /// for it.
  public init(executor: any ThreadAffinityExecutor) {
    self.executor = executor
    self.ownedExecutor = nil
    self.migratingExecutor = executor as? MigratingThreadExecutor
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    openRuntimeSynchronously()
  }

  public init(executor: any ThreadAffinityExecutor, _ mode: JSInitMode) async {
    self.executor = executor
    self.ownedExecutor = nil
    self.migratingExecutor = executor as? MigratingThreadExecutor
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    await openRuntime()
  }

  /// Whether the caller is isolated with respect to this VM's executor. A
  /// thread-affinity executor answers with thread identity on every supported
  /// platform.
  package nonisolated func isOnVMExecutor() -> Bool {
    executor.isIsolatingCurrentContext() == true
  }

  /// Create the runtime if it does not exist yet. Engine work: the caller runs
  /// on the VM executor — inline when `isOnVMExecutor()`, or through
  /// `JSExecutorHop` otherwise.
  private nonisolated func makeRuntimeOnExecutor() {
    runtimeBox.withLock { bits in
      guard bits == 0 else { return }
      let runtime = QJSEngine.makeRuntime()
      bits = UInt(bitPattern: runtime)
      registerMigrationHook(runtime)
    }
  }

  /// QuickJS records the stack top of the current thread. A migrated runtime
  /// refreshes it on the entering thread before any JS runs there; the handler
  /// captures the runtime bits and the counter only, never this VM.
  private nonisolated func registerMigrationHook(_ runtime: OpaquePointer) {
    guard let migratingExecutor else { return }
    let runtimeBits = UInt(bitPattern: runtime)
    let refreshes = migrationRefreshes
    migrationHook = migratingExecutor.addObserver(
      for: .enteringBoundThread,
      queue: nil
    ) { _ in
      guard let runtime = OpaquePointer(bitPattern: runtimeBits) else { return }
      JS_UpdateStackTop(runtime)
      refreshes.value.wrappingAdd(1, ordering: .relaxed)
    }
  }

  /// The number of `.enteringBoundThread` refreshes performed so far.
  package nonisolated func migrationRefreshCount() -> UInt64 {
    migrationRefreshes.value.load(ordering: .relaxed)
  }

  private nonisolated func runtimeHandleOnExecutor() -> OpaquePointer {
    makeRuntimeOnExecutor()
    return OpaquePointer(bitPattern: runtimeBox.withLock { $0 })!
  }

  /// The engine context for a new `QJSContext`, created on the VM executor.
  /// Returns the raw pointer as `UInt`: the handle crosses isolation, and
  /// `UInt` is the Sendable form of an engine reference.
  package nonisolated func makeContextOnExecutor() -> UInt? {
    let runtime = runtimeHandleOnExecutor()
    guard let context = QJSEngine.makeContext(in: runtime) else { return nil }
    return UInt(bitPattern: context)
  }

  /// Isolated form for callers that come through the actor (tests).
  package func makeContext() -> UInt? {
    makeContextOnExecutor()
  }

  /// Force a QuickJS cycle collection on the VM executor.
  package func gc() {
    let runtime = runtimeHandleOnExecutor()
    JS_UpdateStackTop(runtime)
    JS_RunGC(runtime)
  }

  /// The runtime pointer as bits, for engine-inspecting package tests.
  package func runtimeBits() -> UInt {
    UInt(bitPattern: runtimeHandleOnExecutor())
  }

  /// Ensure the runtime exists: inline when already isolated on the executor,
  /// otherwise enqueue on the executor and block the caller until the engine
  /// work completed.
  ///
  /// The executor is a task executor here, so the job is enqueued immediately
  /// (SE-0417) and needs no cooperative-pool thread.
  private nonisolated func openRuntimeSynchronously() {
    if isOnVMExecutor() {
      makeRuntimeOnExecutor()
      return
    }
    let done = DispatchSemaphore(value: 0)
    scheduleOnTaskExecutor(executor) { [self] in
      makeRuntimeOnExecutor()
      done.signal()
    }
    done.wait()
  }

  /// Async form: the same hop, awaited instead of blocked.
  private nonisolated func openRuntime() async {
    if isOnVMExecutor() {
      makeRuntimeOnExecutor()
      return
    }
    await runOnTaskExecutor(executor) { [self] in
      makeRuntimeOnExecutor()
    }
  }

  /// Isolated deinit (SE-0371): runs on the VM executor, after every context
  /// released its own reference, so the teardown needs no bridge.
  isolated deinit {
    migrationHook?.remove()
    let bits = runtimeBox.withLock { $0 }
    if let runtime = OpaquePointer(bitPattern: bits) {
      QJSEngine.releaseRuntime(runtime)
      removeQuickJSClassRecords(in: runtime)
    }
    if let ownedExecutor {
      // The last reference can drop on the VM thread itself: a context's
      // isolated deinit ends there and drops the VM it retained. Nobody is
      // left to join that thread, so hand the shutdown to a global-queue
      // thread; elsewhere stop it here, draining queued work first.
      if ownedExecutor.threadID == ThreadID.current {
        DispatchQueue.global().async {
          ownedExecutor.shutdown()
        }
      } else {
        ownedExecutor.shutdown()
      }
    }
  }

  public nonisolated static func == (lhs: QJSVirtualMachine, rhs: QJSVirtualMachine) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

/// Retained by the migration observer; holding the counter in a class keeps
/// the handler from capturing the VM and closing a reference cycle.
private final class MigrationRefreshCounter: @unchecked Sendable {
  let value = Atomic<UInt64>(0)
}
