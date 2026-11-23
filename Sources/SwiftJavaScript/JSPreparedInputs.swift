/// Scope witness capability. Signatures such as `borrowHandle(in:)` require
/// the *ability* to address a driver context handle, not a specific scope
/// type; `JSInstantContext` and `JSScope` both conform. Fabricating a
/// temporary scope just to satisfy such a signature is unnecessary by design.
internal protocol JSScopeWitness<Engine>: ~Copyable {
  associatedtype Engine: JSEngineRuntimeDriver
  var driverContextHandle: Engine.ContextHandle { get }
  /// The witness's own arena frame. Persistent-handle resolution anchors its
  /// produced local view here (design §5.1/§5.2).
  var scopeFrame: ScopeFrame<Engine> { get }
}

public struct JSPropertyStringKey<E: JSEnginePropertyDriver>: Sendable, ~Copyable {
  package let handle: E.PropertyStringKeyHandle
  private let contextHandle: E.ContextHandle
  /// The VM thread of the context that created the key, when it has one. The
  /// key retains the engine context, so it can outlive the `JSContext` actor
  /// — and with it the scope-stack entry that maps a context to its VM
  /// thread; the thread has to be remembered here for the release.
  private let vmThread: VMThread?

  init(
    handle: E.PropertyStringKeyHandle,
    context: E.ContextHandle,
    vmThread: VMThread? = nil
  ) {
    self.handle = handle
    self.contextHandle = context
    self.vmThread = vmThread
    _ = contextHandle.retainReference()
  }

  func borrowHandle<W: JSScopeWitness<E> & ~Copyable>(in witness: borrowing W)
    -> E.PropertyStringKeyHandle
  {
    borrowHandle(in: witness.driverContextHandle)
  }

  /// Self-addressed borrowing: context-scoped values (`JSCallbackValue`)
  /// validate against the context handle they carry themselves.
  func borrowHandle(in contextHandle: E.ContextHandle) -> E.PropertyStringKeyHandle {
    precondition(
      contextHandle.isPropertyStringKeyHandleCompatibleWithContext(handle),
      "JSPropertyStringKey can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    // Engine calls — the context reference may be the context's last.
    let handle = self.handle
    let contextHandle = self.contextHandle
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
}

public struct JSPreparedScript<E: JSEnginePreparedScriptDriver>: Sendable, ~Copyable {
  package let handle: E.PreparedScriptHandle
  private let contextHandle: E.ContextHandle
  /// The VM thread of the context that compiled the script, when it has one.
  /// Same reason as `JSPropertyStringKey.vmThread`: the script retains the
  /// engine context and can outlive the `JSContext` actor.
  private let vmThread: VMThread?

  init(
    handle: E.PreparedScriptHandle,
    context: E.ContextHandle,
    vmThread: VMThread? = nil
  ) {
    self.handle = handle
    self.contextHandle = context
    self.vmThread = vmThread
    _ = contextHandle.retainReference()
  }

  func borrowHandle<W: JSScopeWitness<E> & ~Copyable>(in witness: borrowing W)
    -> E.PreparedScriptHandle
  {
    borrowHandle(in: witness.driverContextHandle)
  }

  /// Self-addressed borrowing: context-scoped values (`JSCallbackValue`)
  /// validate against the context handle they carry themselves.
  func borrowHandle(in contextHandle: E.ContextHandle) -> E.PreparedScriptHandle {
    precondition(
      contextHandle.isPreparedScriptHandleCompatibleWithContext(handle),
      "JSPreparedScript can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    // Engine calls — the context reference may be the context's last.
    let handle = self.handle
    let contextHandle = self.contextHandle
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
}
