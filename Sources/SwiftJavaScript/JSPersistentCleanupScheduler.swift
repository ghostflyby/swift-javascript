/// Scheduler face used by the persistent-binding registry to run settlement
/// on the VM's dedicated serial executor (design §2.4 option b).
///
/// Cleanup closures and actor jobs share one OS thread, so "the payload is
/// only touched on the VM thread" (§3.5) holds by construction. A stopped
/// executor drops late closures: every binding was already settled inline by
/// `close()` before the executor's owner shuts the thread down.
///
/// Engine-agnostic: `VMThread` conforms, and each engine's VM exposes itself
/// as a scheduler. The registry that consumes it now lives in each engine's
/// module.
package protocol JSPersistentCleanupScheduler: Sendable {
  func schedulePersistentCleanup(_ body: @escaping @Sendable () -> Void)
}
