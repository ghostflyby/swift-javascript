/// A temporary actor whose isolated method runs on a caller-supplied serial
/// executor: awaiting `run` hands the closure to the executor as one job.
///
/// The VM and context initializers use one when the caller is not already
/// isolated on the target executor: a synchronous init blocks a semaphore
/// while the hop runs the engine work, an async init awaits it. This works for
/// every `SerialExecutor` — the hop is an actor job, so neither a
/// `TaskExecutor` conformance nor a thread-identity check is needed.
package actor JSExecutorHop {
  package nonisolated let unownedExecutor: UnownedSerialExecutor

  package init(executor: any SerialExecutor) {
    self.unownedExecutor = executor.asUnownedSerialExecutor()
  }

  /// Run `body` on the executor.
  package func run(_ body: @Sendable () -> Void) {
    body()
  }
}

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

/// Fire-and-forget `body` on a serial executor.
///
/// A task executor takes the body directly and in order (immediate enqueue).
/// Any other serial executor has no way to accept a closure, so a temporary
/// `JSExecutorHop` carries it; that fallback is ordered only from the moment
/// the hop job is accepted.
package func scheduleOnSerialExecutor(
  _ executor: any SerialExecutor,
  _ body: @escaping @Sendable () -> Void
) {
  if let taskExecutor = executor as? any TaskExecutor {
    scheduleOnTaskExecutor(taskExecutor, body)
    return
  }
  let hop = JSExecutorHop(executor: executor)
  Task {
    await hop.run(body)
  }
}
