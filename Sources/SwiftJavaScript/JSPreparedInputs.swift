/// Scope witness capability. Signatures such as `borrowHandle(in:)` require
/// the *ability* to address a driver context handle, not a specific scope
/// type; `JSInstantContext` and `JSScope` both conform. Fabricating a
/// temporary scope just to satisfy such a signature is unnecessary by design.
internal protocol JSScopeWitness<Engine>: ~Copyable {
  associatedtype Engine: JSEngine
  var driverContextHandle: Engine.ContextHandle { get }
}

public struct JSPropertyStringKey<E: JSEngine>: Sendable, ~Copyable {
  package let handle: E.PropertyStringKeyHandle
  private let contextHandle: E.ContextHandle

  init(handle: E.PropertyStringKeyHandle, context: E.ContextHandle) {
    self.handle = handle
    self.contextHandle = context
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
      E.isPropertyStringKeyHandleCompatibleWithContext(handle, in: contextHandle),
      "JSPropertyStringKey can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    _ = handle.releaseReference()
    _ = contextHandle.releaseReference()
  }
}

public struct JSPreparedScript<E: JSEngine>: Sendable, ~Copyable {
  package let handle: E.PreparedScriptHandle
  private let contextHandle: E.ContextHandle

  init(handle: E.PreparedScriptHandle, context: E.ContextHandle) {
    self.handle = handle
    self.contextHandle = context
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
      E.isPreparedScriptHandleCompatibleWithContext(handle, in: contextHandle),
      "JSPreparedScript can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    _ = handle.releaseReference()
    _ = contextHandle.releaseReference()
  }
}
