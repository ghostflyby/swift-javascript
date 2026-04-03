import Dispatch

public class JSEngineVirtualMachine<E: JSEngine>: @unchecked Sendable {
  package let driverRuntimeHandle: E.RuntimeHandle
  private let executor: SingleThreadExecutor
  public let unownedExecutor: UnownedSerialExecutor

  public init() {
    self.driverRuntimeHandle = E.makeRuntimeHandle()
    let executor = SingleThreadExecutor()
    self.executor = executor
    self.unownedExecutor = executor.asUnownedSerialExecutor()
  }

  deinit {
    _ = driverRuntimeHandle.releaseReference()
  }
}

extension JSEngineVirtualMachine: Equatable where E.RuntimeHandle: Equatable {
  public static func == (lhs: JSEngineVirtualMachine<E>, rhs: JSEngineVirtualMachine<E>) -> Bool {
    lhs.driverRuntimeHandle == rhs.driverRuntimeHandle
  }
}

extension JSEngineVirtualMachine: Hashable where E.RuntimeHandle: Hashable {

  public func hash(into hasher: inout Hasher) {
    hasher.combine(driverRuntimeHandle)
  }
}

@available(macOS 14.0, *)
// FIXME: actually implement a single-threaded executor
private class SingleThreadExecutor: SerialExecutor, @unchecked Sendable {
  private let queue = DispatchQueue(label: "SwiftyJavaScriptCore.SingleThreadExecutor")

  func enqueue(_ job: consuming ExecutorJob) {
    let unownedJob = UnownedJob(job)
    let unownedExecutor = asUnownedSerialExecutor()
    queue.async {
      unownedJob.runSynchronously(on: unownedExecutor)
    }
  }
}
