import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreBackendDriverHandleReferenceCountingChain() {
  let runtimeHandle = JavaScriptCoreEngine.makeRuntimeHandle()
  #expect(runtimeHandle.retainReference())
  #expect(runtimeHandle.releaseReference())

  guard
    let contextHandle = JavaScriptCoreEngine.makeBorrowedContextHandleFromRuntime(
      in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  #expect(contextHandle.retainReference())
  #expect(contextHandle.releaseReference())

  // Release the creation-time references so this test does not leak engine objects.
  #expect(contextHandle.releaseReference())
  #expect(runtimeHandle.releaseReference())
}
