import Testing
import ThreadAffinityExecutor

@testable import SwiftyQuickJS

/// QuickJS records its stack top per OS thread, so a migrating executor is
/// supported only because the VM refreshes it on every thread hand-off. Deep
/// recursion exercises the recorded stack limit: with a stale top the check
/// would reject valid recursion on the new thread.
@Test func quickJSFollowsAMigratingThreadExecutor() async throws {
  let first = DedicatedThreadExecutor(name: "qjs-migrating-first")
  let second = DedicatedThreadExecutor(name: "qjs-migrating-second")
  let migrating = MigratingThreadExecutor(bound: first)
  let virtualMachine = await QJSVirtualMachine(executor: migrating, .nonblocking)
  let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

  // Deep-enough recursion stays far below QuickJS's recorded stack limit
  // (1 MB default) and the worker thread's own stack.
  let depthScript = "function depth(n) { return n === 0 ? 0 : 1 + depth(n - 1) } depth(200)"

  func evaluateDepth() async -> Double {
    await context.withInstantContext { scope in
      let result = scope.evaluateScript(depthScript)
      switch consume result {
      case .value(let value):
        return value.toNumber()
      case .exception:
        return -1
      }
    }
  }

  #expect(await evaluateDepth() == 200)
  #expect(virtualMachine.migrationRefreshCount() == 0)

  try await migrating.migrate(to: second)
  #expect(migrating.currentThreadID == second.threadID)

  // The entering notification refreshed the stack top on the new thread
  // before the released jobs ran.
  #expect(virtualMachine.migrationRefreshCount() == 1)
  #expect(await evaluateDepth() == 200)

  // Persistent bindings and self-owning inputs keep working across the
  // migration.
  let handle = await context.withInstantContext { scope in
    scope.makePersistentHandle(scope.makeString("migrated"))
  }
  let resolved = await context.withInstantContext { scope in
    guard let value = scope.resolve(handle) else { return "<nil>" }
    return value.toString()
  }
  #expect(resolved == "migrated")
  #expect(handle.invalidate())
}
