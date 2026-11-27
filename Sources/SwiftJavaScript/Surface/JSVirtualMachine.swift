/// The virtual machine that owns a JS runtime and its executor.
///
/// The concrete type is the engine's VM actor (`JSCVirtualMachine`,
/// `QJSVirtualMachine`): engine state is created during `init`, on the VM's
/// executor. The synchronous initializers return once the runtime exists —
/// running the creation inline when the caller already is the executor, and
/// otherwise blocking the calling thread (callers on the concurrency runtime
/// should use the non-blocking `init(_: JSInitMode)` form instead).
///
/// Engines require different executor guarantees, loosest first:
///
/// - Any `SerialExecutor`: engines that serialize engine access internally.
///   JavaScriptCore locks its context group, so its VM accepts any serial
///   executor.
/// - Any `ThreadAffinityExecutor`: engines whose stack bookkeeping needs a
///   known current OS thread — a thread-bound executor, or a migrating one
///   whose thread hand-offs the engine observes. QuickJS refreshes its
///   recorded stack top on every hand-off.
/// - Any `ThreadBoundExecutor`: engines with no internal locking and no
///   migration support, which must stay on one OS thread (a future
///   SpiderMonkey backend).
///
/// The protocol stays a plain `AnyObject`/`Sendable` face because a
/// synchronous actor initializer cannot be a requirement of an
/// `Actor`-inheriting protocol; both concrete VMs are actors nonetheless.
public protocol JSVirtualMachine: AnyObject, Sendable, Hashable {
  /// The context type this VM creates.
  associatedtype Context: JSContext
  where Context.VirtualMachine == Self

  /// Create a VM with its own dedicated thread and a runtime created during
  /// init. Blocks the calling thread until the runtime exists (or runs inline
  /// when already isolated on the executor).
  ///
  /// An executor that cannot report isolation (a plain `SerialExecutor` on
  /// systems without `SerialExecutor.isIsolatingCurrentContext`) is treated as
  /// foreign, so the blocking form must not be called from one of that
  /// executor's own jobs; use `init(_: JSInitMode)` there.
  init()

  /// Non-blocking form: awaits runtime creation on the VM executor instead of
  /// blocking the calling thread.
  init(_ mode: JSInitMode) async

  /// The VM's serial executor. Contexts of this VM are actors on it, so
  /// engine access is serialized on it.
  nonisolated var unownedExecutor: UnownedSerialExecutor { get }
}
