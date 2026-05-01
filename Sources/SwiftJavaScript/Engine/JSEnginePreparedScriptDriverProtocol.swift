public protocol JSEnginePreparedScriptDriver: JSEngineRuntimeDriver {
  associatedtype PreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle

  static func makePreparedScriptHandle(
    _ source: String,
    in context: ContextHandle
  ) -> PreparedScriptHandle?

  static func isPreparedScriptHandleCompatibleWithContext(
    _ script: PreparedScriptHandle,
    in context: ContextHandle
  ) -> Bool

  static func evaluatePreparedScriptResultHandle(
    _ script: PreparedScriptHandle,
    _ context: ContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<ValueHandle>?
}
