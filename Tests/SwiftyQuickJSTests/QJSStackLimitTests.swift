import Testing

@testable import SwiftyQuickJS

/// QuickJS records the stack top when the runtime is created on the VM
/// executor and refreshes it only on thread hand-offs. The logical budget is
/// 256 KiB — below the dedicated thread's own stack — so recursion is stopped
/// by the engine check (as a catchable exception) instead of overflowing the
/// native stack, without any per-engine-call stack-top refresh.
@Test func quickJSStackLimitFiresOnTheVMThread() async {
  let virtualMachine = await QJSVirtualMachine(.nonblocking)
  let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

  let result = await context.withInstantContext { scope in
    let evaluated = scope.evaluateScript(
      """
      function depth(n) { return n === 0 ? 0 : 1 + depth(n - 1) }
      var shallow = depth(200);
      var deep;
      try { depth(100000); deep = "uncaught" } catch (error) { deep = "caught:" + error.name }
      shallow + "/" + deep
      """
    )
    switch consume evaluated {
    case .value(let value):
      return value.toString()
    case .exception(let exception):
      return "script-exception:" + exception.toString()
    }
  }

  #expect(result == "200/caught:RangeError")
}
