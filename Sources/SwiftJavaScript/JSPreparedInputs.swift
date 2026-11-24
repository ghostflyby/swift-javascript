// MARK: - Self-owning input release (S9)
//
// Property string keys and prepared scripts keep the engine context alive, so
// they can outlive the `JSContext` actor. The engine calls of their teardown
// (`JSStringRelease` / `JS_FreeAtom` / `JS_DupContext`+`JS_FreeContext`) must
// run on the VM thread that owns the engine, and the thread has to be
// remembered because the context's scope-stack binding may already be gone by
// the time the input is dropped.
//
// Both engine input types (`JSCPropertyStringKey`, `QJSPreparedScript`, …)
// share this algorithm.

/// Release one self-owning input: its engine handle first, then the context
/// reference it retains. Routed to `vmThread` when the creating context had
/// one, run inline otherwise (a bare engine context without a VM thread).
package func releasePreparedInput<
  Handle: JSManualReferenceCountedHandle,
  ContextHandle: JSContextManualReferenceCountedHandle
>(
  handle: Handle,
  contextHandle: ContextHandle,
  vmThread: VMThread?
) {
  // The context reference may be the context's last: both engine calls belong
  // together on the VM thread, never split across threads.
  let release: @Sendable () -> Void = {
    _ = handle.releaseReference()
    _ = contextHandle.releaseReference()
  }
  if let vmThread {
    vmThread.perform(release)
  } else {
    release()
  }
}
