public struct JSPropertyKey<E: JSEngine>: @unchecked Sendable, ~Copyable {
  package let handle: E.PropertyKeyHandle
  private let contextHandle: E.ContextHandle

  package init(handle: E.PropertyKeyHandle, context: E.ContextHandle) {
    self.handle = handle
    self.contextHandle = context
    _ = contextHandle.retainReference()
  }

  package func borrowHandle(in context: borrowing JSInstantContext<E>) -> E.PropertyKeyHandle {
    precondition(
      E.isPropertyKeyHandleCompatibleWithContext(handle, in: context.driverContextHandle),
      "JSPropertyKey can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    _ = handle.releaseReference()
    _ = contextHandle.releaseReference()
  }
}

public struct JSPreparedScript<E: JSEngine>: @unchecked Sendable, ~Copyable {
  package let handle: E.PreparedScriptHandle
  private let contextHandle: E.ContextHandle

  package init(handle: E.PreparedScriptHandle, context: E.ContextHandle) {
    self.handle = handle
    self.contextHandle = context
    _ = contextHandle.retainReference()
  }

  package func borrowHandle(in context: borrowing JSInstantContext<E>) -> E.PreparedScriptHandle {
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
