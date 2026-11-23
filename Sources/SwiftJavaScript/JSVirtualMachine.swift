import Dispatch
import Foundation
import Synchronization

public final class JSVirtualMachine<E: JSEngineRuntimeDriver>: Sendable {
  package let driverRuntimeHandle: E.RuntimeHandle
  private let owner: DedicatedThreadSerialExecutor.Owner
  /// Retained so registry cleanup jobs can be scheduled without retaining the
  /// VM itself; the `Owner` is what shuts the thread down.
  private let executor: DedicatedThreadSerialExecutor
  public let unownedExecutor: UnownedSerialExecutor

  public convenience init() {
    self.init(executor: DedicatedThreadSerialExecutor())
  }

  private init(executor: DedicatedThreadSerialExecutor) {
    self.driverRuntimeHandle = E.makeRuntimeHandle()
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    self.owner = executor.owner
    self.executor = executor
  }

  /// Scheduling handle for persistent-binding settlement (design §2.4
  /// option b). Cleanup closures run on the same serial OS thread as actor
  /// jobs, so payload settlement never escapes the VM thread.
  package var persistentCleanupScheduler: any JSPersistentCleanupScheduler {
    executor
  }

  deinit {
    _ = driverRuntimeHandle.releaseReference()
  }
}

extension JSVirtualMachine: Equatable where E.RuntimeHandle: Equatable {
  public static func == (lhs: JSVirtualMachine<E>, rhs: JSVirtualMachine<E>) -> Bool {
    lhs.driverRuntimeHandle == rhs.driverRuntimeHandle
  }
}

extension JSVirtualMachine: Hashable where E.RuntimeHandle: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(driverRuntimeHandle)
  }
}

private final class DedicatedThreadSerialExecutor: Thread, SerialExecutor,
  JSPersistentCleanupScheduler, @unchecked Sendable
{
  struct State {
    var jobs: [UnownedJob] = []
    /// Registry settlement jobs (design §2.4 option b). They share this
    /// thread with actor jobs, which is what keeps payloads VM-thread-only.
    var cleanupJobs: [@Sendable () -> Void] = []
    var stopped = false
  }
  let state = Mutex(State())
  let semaphore = DispatchSemaphore(value: 0)
  let threadStopSemaphore = DispatchSemaphore(value: 0)

  override init() {
    super.init()
    self.start()
  }

  override func main() {
    let executor = self.asUnownedSerialExecutor()
    defer { threadStopSemaphore.signal() }

    while true {
      semaphore.wait()

      let (cleanup, job, shouldStop) = state.withLock {
        state
          -> (
            cleanup: (@Sendable () -> Void)?,
            job: UnownedJob?,
            shouldStop: Bool
          ) in
        // Cleanup runs before the next actor job on the same thread.
        if !state.cleanupJobs.isEmpty {
          return (state.cleanupJobs.removeFirst(), nil, false)
        }
        if !state.jobs.isEmpty {
          return (nil, state.jobs.removeFirst(), false)
        }
        return (nil, nil, state.stopped)
      }

      if let cleanup {
        cleanup()
        continue
      }

      if let job {
        job.runSynchronously(on: executor)
      } else if shouldStop {
        return
      }
    }
  }

  public nonisolated func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    let shouldSignal = state.withLock {
      if $0.stopped { return false }
      $0.jobs.append(unownedJob)
      return true
    }

    if shouldSignal {
      semaphore.signal()
    }
  }

  /// Enqueue a settlement closure. After `stopped`, the closure is dropped:
  /// every binding was settled inline by `close()` before shutdown, so
  /// dropping cannot leak an engine reference (design §2.4).
  func schedulePersistentCleanup(_ body: @escaping @Sendable () -> Void) {
    let shouldSignal = state.withLock {
      if $0.stopped { return false }
      $0.cleanupJobs.append(body)
      return true
    }

    if shouldSignal {
      semaphore.signal()
    }
  }

  public nonisolated func asUnownedSerialExecutor() -> UnownedSerialExecutor {
    .init(ordinary: self)
  }

  private func shutdown() {
    state.withLock {
      $0.stopped = true
    }
    semaphore.signal()
  }

  struct Owner: ~Copyable {
    let thread: DedicatedThreadSerialExecutor
    deinit {
      thread.shutdown()
      if Thread.current != thread {
        thread.threadStopSemaphore.wait()
      }
    }
  }

  var owner: Owner {
    Owner(thread: self)
  }

}
