public struct JSPropertyStringKey<E: JSEngine>: Sendable, ~Copyable {
  package let handle: E.PropertyStringKeyHandle
  private let contextHandle: E.ContextHandle

  init(handle: E.PropertyStringKeyHandle, context: E.ContextHandle) {
    self.handle = handle
    self.contextHandle = context
    _ = contextHandle.retainReference()
  }

  func borrowHandle(in context: borrowing JSInstantContext<E>) -> E.PropertyStringKeyHandle {
    precondition(
      E.isPropertyStringKeyHandleCompatibleWithContext(handle, in: context.driverContextHandle),
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

  func borrowHandle(in context: borrowing JSInstantContext<E>) -> E.PreparedScriptHandle {
    precondition(
      E.isPreparedScriptHandleCompatibleWithContext(handle, in: context.driverContextHandle),
      "JSPreparedScript can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    _ = handle.releaseReference()
    _ = contextHandle.releaseReference()
  }
}
