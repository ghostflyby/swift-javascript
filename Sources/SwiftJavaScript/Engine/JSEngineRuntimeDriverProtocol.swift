public protocol JSEngineRuntimeDriver {
  associatedtype Engine: JSEngine = Self
  associatedtype RuntimeHandle: JSRuntimeManualReferenceCountedHandle
  associatedtype ContextHandle: JSContextManualReferenceCountedHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  associatedtype ClassHandle: JSClassManualReferenceCountedHandle

  static var capabilities: JSEngineCapabilities { get }

  static func makeRuntimeHandle() -> RuntimeHandle
  static func makeBorrowedContextHandleFromRuntime(in runtime: RuntimeHandle) -> ContextHandle?

  static func globalObjectValueHandle(_ context: ContextHandle) -> ValueHandle?

  static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSRetainedFunctionCallback<Engine>,
    in context: ContextHandle
  ) -> ValueHandle?

  @_lifetime(immortal)
  static func evaluateScriptResultHandle(
    _ script: String,
    _ context: ContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<ValueHandle>?

  static func valueTypeForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> JSType?

  static func toBooleanForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func toNumberForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Double

  static func toStringForHandle(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> String?

  static func makeStringValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeSymbolValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeNumberValueHandle(
    _ value: Double,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeNullValueHandle(
    _ context: ContextHandle
  ) -> ValueHandle?

  static func makeUndefinedValueHandle(
    _ context: ContextHandle
  ) -> ValueHandle?

  @_lifetime(immortal)
  static func makeObjectResultHandle(
    _ context: ContextHandle
  ) -> JSResult<ValueHandle>?

  @_lifetime(immortal)
  static func makeArrayResultHandle(
    _ context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func isValueHandleCompatibleWithContext(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool
}

extension JSEngineRuntimeDriver {
  public static func isValueHandleCompatibleWithContext(
    _ value: ValueHandle,
    in context: ContextHandle
  ) -> Bool {
    _ = value
    _ = context
    return true
  }
}
