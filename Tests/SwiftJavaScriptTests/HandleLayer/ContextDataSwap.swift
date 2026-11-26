import SwiftJavaScript

// MARK: - VM-thread routing

extension JSEngineRuntimeDriver {
  /// Install, replace, or clear a context's data storage box without ever
  /// touching the engine off the context's VM thread.
  ///
  /// `raw` mutates engine state (JSC `JSObjectSetPrivate` on the global
  /// object, QuickJS `JS_SetContextOpaque`) and releases the displaced box, so
  /// it belongs on the VM thread (design §0.2.3). A context bound to a VM
  /// thread — every host `JSContext` actor, from the end of its `init` to its
  /// isolated deinit — swaps inline when the caller already is that thread and
  /// otherwise posts the swap to the VM thread's queue: the calling thread
  /// makes no engine call, and the swap lands ahead of anything enqueued
  /// after it, which also means the call returns before it takes effect. A
  /// context with no host actor has no VM thread to protect and swaps
  /// inline.
  package static func swapContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    on context: ContextHandle,
    raw: @escaping @Sendable (ContextHandle, JSContextDataStorageBox?) -> Void
  ) {
    guard let vmThread = ScopeStackRegistry<ContextHandle>.vmThread(for: context) else {
      raw(context, storage)
      return
    }
    vmThread.perform {
      raw(context, storage)
    }
  }
}
