import SwiftJavaScript

/// A self-owning JavaScriptCore property string key.
///
/// Keeps the `JSStringRef` alive plus a reference to the context that created
/// it, so the key can outlive `JSCContext`/`JSCInstantContext`. The release is
/// routed to the context's VM thread when it has one; the shared algorithm is
/// `releasePreparedInput` in core.
public struct JSCPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = JSCContext
  public typealias ContextHandle = JSCContextHandle
  public typealias Handle = JSCPropertyStringKeyHandle

  package let handle: JSCPropertyStringKeyHandle
  private let contextHandle: JSCContextHandle
  private let vmThread: VMThread?

  package init(
    handle: JSCPropertyStringKeyHandle,
    contextHandle: JSCContextHandle,
    vmThread: VMThread?
  ) {
    self.handle = handle
    self.contextHandle = contextHandle
    self.vmThread = vmThread
    _ = contextHandle.retainReference()
  }

  public borrowing func borrowHandle(
    in contextHandle: JSCContextHandle
  ) -> JSCPropertyStringKeyHandle {
    precondition(
      contextHandle.isPropertyStringKeyHandleCompatibleWithContext(handle),
      "JSCPropertyStringKey can only be used with the context that created it"
    )
    return handle
  }

  deinit {
    releasePreparedInput(
      handle: handle,
      contextHandle: contextHandle,
      vmThread: vmThread
    )
  }
}

/// A self-owning JavaScriptCore prepared script.
///
/// JavaScriptCore caches the script as a `JSStringRef`; the wrapper owns that
/// reference and a context reference, exactly like `JSCPropertyStringKey`.
public struct JSCPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = JSCContext
  public typealias ContextHandle = JSCContextHandle
  public typealias Handle = JSCPreparedScriptHandle

  package let handle: JSCPreparedScriptHandle
  private let contextHandle: JSCContextHandle
  private let vmThread: VMThread?

  package init(
    handle: JSCPreparedScriptHandle,
    contextHandle: JSCContextHandle,
    vmThread: VMThread?
  ) {
    self.handle = handle
    self.contextHandle = contextHandle
    self.vmThread = vmThread
    _ = contextHandle.retainReference()
  }

  public borrowing func borrowHandle(
    in contextHandle: JSCContextHandle
  ) -> JSCPreparedScriptHandle {
    precondition(
      contextHandle.isPreparedScriptHandleCompatibleWithContext(handle),
      "JSCPreparedScript can only be used with the context that compiled it"
    )
    return handle
  }

  deinit {
    releasePreparedInput(
      handle: handle,
      contextHandle: contextHandle,
      vmThread: vmThread
    )
  }
}
