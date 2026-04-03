import Dispatch
import JavaScriptCore.JSVirtualMachine
import SwiftJavaScript

public class JSVirtualMachine: @unchecked Sendable {
  let driverRuntimeHandle: JavaScriptCoreRuntimeHandle
  private let executor: SingleThreadExecutor
  let unownedExecutor: UnownedSerialExecutor

  var peer: JavaScriptCore.JSContextGroupRef {
    driverRuntimeHandle.ref
  }

  public init() {
    self.driverRuntimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
    let executor = SingleThreadExecutor()
    self.executor = executor
    unownedExecutor = executor.asUnownedSerialExecutor()
  }

  deinit {
    _ = driverRuntimeHandle.releaseReference()
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
