import JavaScriptCore.JSVirtualMachine
import Dispatch

public class JSVirtualMachine: @unchecked Sendable {
  let peer: JavaScriptCore.JSContextGroupRef
  private let executor: SingleThreadExecutor
  let unownedExecutor: UnownedSerialExecutor

  public init() {
    self.peer = JavaScriptCore.JSContextGroupCreate()
    let executor = SingleThreadExecutor()
    self.executor = executor
    unownedExecutor = executor.asUnownedSerialExecutor()
  }

  deinit {
    JavaScriptCore.JSContextGroupRelease(peer)
  }

}

extension JSVirtualMachine: Hashable {
  public static func == (lhs: JSVirtualMachine, rhs: JSVirtualMachine) -> Bool {
    return lhs.peer == rhs.peer
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(peer)
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
