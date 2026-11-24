import SwiftJavaScript

/// A self-owning QuickJS property string key.
///
/// Owns one atom reference (`JS_NewAtom` / `JS_FreeAtom`) and keeps the context
/// that created it alive, so the key can outlive `QJSContext`. Release runs on
/// the context's VM thread when it has one (`releasePreparedInput`).
public struct QJSPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = QJSContext
  public typealias ContextHandle = QJSContextHandle
  public typealias Handle = QJSPropertyStringKeyHandle

  package let handle: QJSPropertyStringKeyHandle
  private let contextHandle: QJSContextHandle
  private let vmThread: VMThread?

  package init(
    handle: QJSPropertyStringKeyHandle,
    contextHandle: QJSContextHandle,
    vmThread: VMThread?
  ) {
    self.handle = handle
    self.contextHandle = contextHandle
    self.vmThread = vmThread
    _ = contextHandle.retainReference()
  }

  public borrowing func borrowHandle(
    in contextHandle: QJSContextHandle
  ) -> QJSPropertyStringKeyHandle {
    precondition(
      contextHandle.isPropertyStringKeyHandleCompatibleWithContext(handle),
      "QJSPropertyStringKey can only be used with the context that created it"
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

/// A self-owning QuickJS prepared script.
///
/// QuickJS re-evaluates the cached source, so the engine handle carries the
/// source string and the context ref with no-op retain/release; the wrapper
/// still owns that handle and a context reference for lifetime symmetry with
/// `QJSPropertyStringKey`.
public struct QJSPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = QJSContext
  public typealias ContextHandle = QJSContextHandle
  public typealias Handle = QJSPreparedScriptHandle

  package let handle: QJSPreparedScriptHandle
  private let contextHandle: QJSContextHandle
  private let vmThread: VMThread?

  package init(
    handle: QJSPreparedScriptHandle,
    contextHandle: QJSContextHandle,
    vmThread: VMThread?
  ) {
    self.handle = handle
    self.contextHandle = contextHandle
    self.vmThread = vmThread
    _ = contextHandle.retainReference()
  }

  public borrowing func borrowHandle(
    in contextHandle: QJSContextHandle
  ) -> QJSPreparedScriptHandle {
    precondition(
      contextHandle.isPreparedScriptHandleCompatibleWithContext(handle),
      "QJSPreparedScript can only be used with the context that compiled it"
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
