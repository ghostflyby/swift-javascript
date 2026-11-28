import Dispatch
import Foundation
import Testing
import ThreadAffinityExecutor

@testable import SwiftyJavaScriptCore

/// The VM runs every context of JavaScriptCore on a caller-supplied run-loop
/// thread instead of creating its own.
@Test func javaScriptCoreRunsOnACallerSuppliedRunLoopThread() async {
  let executor = RunLoopThreadExecutor(name: "jsc-caller-run-loop")
  let virtualMachine = await JSCVirtualMachine(executor: executor, .nonblocking)
  let context = await JSCContext(virtualMachine: virtualMachine, .nonblocking)

  let sum = await context.withInstantContext { scope in
    let result = scope.evaluateScript("6 * 7")
    switch consume result {
    case .value(let value):
      return value.toNumber()
    case .exception:
      return -1
    }
  }
  #expect(sum == 42)

  // The persistent-handle path settles through the VM executor, which runs
  // the caller's run loop like every other job.
  let handle = await context.withInstantContext { scope in
    scope.makePersistentHandle(scope.makeString("caller-run-loop"))
  }
  #expect(handle.invalidate())
}

/// The blocking initializers also work with a caller-supplied run-loop thread
/// when the caller is a real thread outside the concurrency runtime.
@Test func javaScriptCoreSynchronousInitOnACallerRunLoopThread() async {
  let state = await withCheckedContinuation {
    (continuation: CheckedContinuation<Bool, Never>) in
    let thread = Thread {
      let executor = RunLoopThreadExecutor(name: "jsc-sync-caller-run-loop")
      let virtualMachine = JSCVirtualMachine(executor: executor)
      let context = JSCContext(virtualMachine: virtualMachine)
      continuation.resume(returning: context.contextDataStorageBox() != nil)
    }
    thread.start()
  }
  #expect(state)
}
