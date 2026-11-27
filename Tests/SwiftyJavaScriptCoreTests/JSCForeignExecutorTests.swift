import Dispatch
import Foundation
import Testing
import ThreadAffinityExecutor

@testable import SwiftyJavaScriptCore

/// A minimal serial executor over a dispatch queue: deliberately neither a
/// `TaskExecutor` nor thread-identifiable. JavaScriptCore locks its context
/// group internally, so this is the loosest executor its VM accepts.
///
/// The instance is process-lived: the VM borrows its executor
/// (`UnownedSerialExecutor`), and the context actor's teardown is scheduled
/// after the test body returns.
private let queueSerialExecutor = QueueSerialExecutor()

private final class QueueSerialExecutor: SerialExecutor, @unchecked Sendable {
  private let queue = DispatchQueue(label: "SwiftyJavaScriptCoreTests.serial")

  func enqueue(_ job: consuming ExecutorJob) {
    let job = UnownedJob(job)
    queue.async { [self] in
      job.runSynchronously(on: asUnownedSerialExecutor())
    }
  }
}

/// The VM runs every context of JavaScriptCore on a caller-supplied dedicated
/// thread instead of creating its own.
@Test func javaScriptCoreRunsOnACallerSuppliedDedicatedThread() async {
  let executor = DedicatedThreadExecutor(name: "jsc-caller-executor")
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

  // The persistent-handle path settles through the context actor, which runs
  // on the caller's executor like every other job.
  let handle = await context.withInstantContext { scope in
    scope.makePersistentHandle(scope.makeString("caller-executor"))
  }
  #expect(handle.invalidate())
}

/// JavaScriptCore's own locking makes the VM safe on any serial executor, not
/// only thread-affine ones: a queue-backed executor with no thread identity
/// and no task-executor conformance still drives a working context.
@Test func javaScriptCoreRunsOnAnySerialExecutor() async {
  let virtualMachine = await JSCVirtualMachine(executor: queueSerialExecutor, .nonblocking)
  let context = await JSCContext(virtualMachine: virtualMachine, .nonblocking)

  let text = await context.withInstantContext { scope in
    let result = scope.evaluateScript("'serial' + '-' + 'executor'")
    switch consume result {
    case .value(let value):
      return value.toString()
    case .exception:
      return "<exception>"
    }
  }
  #expect(text == "serial-executor")
}

/// The blocking initializers also work on a plain serial executor when the
/// caller is a real thread outside the concurrency runtime: the hop task lands
/// on the queue and the caller waits.
@Test func javaScriptCoreSynchronousInitOnAPlainSerialExecutor() async {
  let state = await withCheckedContinuation {
    (continuation: CheckedContinuation<Bool, Never>) in
    let thread = Thread {
      let virtualMachine = JSCVirtualMachine(executor: queueSerialExecutor)
      let context = JSCContext(virtualMachine: virtualMachine)
      continuation.resume(returning: context.contextDataStorageBox() != nil)
    }
    thread.start()
  }
  #expect(state)
}
