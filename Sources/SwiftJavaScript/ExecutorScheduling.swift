/// Schedule `body` on a task executor. SE-0417 makes the task enqueued on the
/// executor immediately, so starting it needs no cooperative-pool thread —
/// the property the blocking initializers and the settlement path rely on.
package func scheduleOnTaskExecutor<E: TaskExecutor & Sendable>(
  _ executor: E,
  _ body: @escaping @Sendable () -> Void
) {
  Task.detached(executorPreference: executor) {
    body()
  }
}

/// Await `body` on a task executor (same immediate enqueue, awaited instead of
/// blocked).
package func runOnTaskExecutor<E: TaskExecutor & Sendable>(
  _ executor: E,
  _ body: @escaping @Sendable () -> Void
) async {
  await Task.detached(executorPreference: executor) {
    body()
  }.value
}
