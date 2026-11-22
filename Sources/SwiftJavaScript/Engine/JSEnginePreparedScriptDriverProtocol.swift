/// Context-side prepared-script operations (Stage 2B decomposition).
public protocol JSContextPreparedScriptDriver: JSContextRuntimeDriver {
  associatedtype PreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle

  func makePreparedScriptHandle(_ source: String) -> PreparedScriptHandle?

  func isPreparedScriptHandleCompatibleWithContext(_ script: PreparedScriptHandle) -> Bool

  func evaluatePreparedScriptResultHandle(
    _ script: PreparedScriptHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<ValueHandle>?
}

/// Engine-side descriptor. Prepared-script requirements now live on
/// `JSContextPreparedScriptDriver`, implemented by `ContextHandle`.
public protocol JSEnginePreparedScriptDriver: JSEngineRuntimeDriver
where
  ContextHandle: JSContextPreparedScriptDriver,
  ContextHandle.PreparedScriptHandle == PreparedScriptHandle
{
  associatedtype PreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle
}
