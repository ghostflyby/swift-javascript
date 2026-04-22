import Dispatch
import Foundation
import Synchronization

public final class JSVirtualMachine<E: JSEngine>: Sendable {
  package let driverRuntimeHandle: E.RuntimeHandle
  private let owner: DedicatedThreadSerialExecutor.Owner
  public let unownedExecutor: UnownedSerialExecutor

  public convenience init() {
    self.init(executor: DedicatedThreadSerialExecutor())
  }

  private init(executor: DedicatedThreadSerialExecutor) {
    self.driverRuntimeHandle = E.makeRuntimeHandle()
    self.unownedExecutor = executor.asUnownedSerialExecutor()
    self.owner = executor.owner
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

private final class DedicatedThreadSerialExecutor: Thread, SerialExecutor, @unchecked Sendable {
  struct State {
    var jobs: [UnownedJob] = []
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

      let (job, shouldStop) = state.withLock { state in
        if !state.jobs.isEmpty {
          return (state.jobs.removeFirst() as UnownedJob?, false)
        }
        return (nil, state.stopped)
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
