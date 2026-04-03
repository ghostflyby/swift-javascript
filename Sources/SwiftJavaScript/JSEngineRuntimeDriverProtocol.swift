public protocol _JSEngineRuntimeDriver {
  associatedtype Engine: JSEngine = Self
  associatedtype RuntimeHandle: JSRuntimeManualReferenceCountedHandle
  associatedtype ContextHandle: JSContextManualReferenceCountedHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle

  static var capabilities: JSEngineCapabilities { get }

  static func makeRuntimeHandle() -> RuntimeHandle
  static func makeBorrowedContextHandleFromRuntime(in runtime: RuntimeHandle) -> ContextHandle?

  static func evaluateScriptResultHandle(
    _ script: String,
    _ context: ContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResultPayload<ValueHandle>?

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

  static func makeObjectResultHandle(
    _ context: ContextHandle
  ) -> JSResultPayload<ValueHandle>?

  static func makeArrayResultHandle(
    _ context: ContextHandle
  ) -> JSResultPayload<ValueHandle>?
}

extension _JSEngineRuntimeDriver {
  public static var capabilities: JSEngineCapabilities { .init() }

  public static func makeRuntimeHandle() -> RuntimeHandle {
    fatalError("_JSEngineRuntimeDriver.makeRuntimeHandle() is not implemented")
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: RuntimeHandle
  ) -> ContextHandle? {
    fatalError(
      "_JSEngineRuntimeDriver.makeBorrowedContextHandleFromRuntime(in:) is not implemented")
  }

  public static func evaluateScriptResultHandle(
    _ script: String,
    _ context: ContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResultPayload<ValueHandle>? {
    fatalError(
      "_JSEngineRuntimeDriver.evaluateScriptResultHandle(_:_:sourceURL:startingLineNumber:) is not implemented"
    )
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineRuntimeDriver.makeStringValueHandle(_:_:) is not implemented")
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineRuntimeDriver.makeSymbolValueHandle(_:_:) is not implemented")
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineRuntimeDriver.makeNumberValueHandle(_:_:) is not implemented")
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineRuntimeDriver.makeBooleanValueHandle(_:_:) is not implemented")
  }

  public static func makeNullValueHandle(
    _ context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineRuntimeDriver.makeNullValueHandle(_:) is not implemented")
  }

  public static func makeUndefinedValueHandle(
    _ context: ContextHandle
  ) -> ValueHandle? {
    fatalError("_JSEngineRuntimeDriver.makeUndefinedValueHandle(_:) is not implemented")
  }

  public static func makeObjectResultHandle(
    _ context: ContextHandle
  ) -> JSResultPayload<ValueHandle>? {
    fatalError("_JSEngineRuntimeDriver.makeObjectResultHandle(_:) is not implemented")
  }

  public static func makeArrayResultHandle(
    _ context: ContextHandle
  ) -> JSResultPayload<ValueHandle>? {
    fatalError("_JSEngineRuntimeDriver.makeArrayResultHandle(_:) is not implemented")
  }
}
