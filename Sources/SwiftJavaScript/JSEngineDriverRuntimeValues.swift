extension _JSEngineDriver where RawRuntime: Sendable, RawContext: Sendable, RawValue: Sendable {
  package static func makeRuntimeHandle() -> JSRuntimeHandle<Engine> {
    JSRuntimeHandle<Engine>(_opaqueHandle: makeRuntime())
  }

  package static func makeBorrowedContextHandleFromRuntime(
    in runtime: JSRuntimeHandle<Engine>
  ) -> JSBorrowedContextHandle<Engine>? {
    guard let rawRuntime: RawRuntime = runtime.opaqueHandle() else {
      return nil
    }
    return JSBorrowedContextHandle<Engine>(_opaqueHandle: makeContext(in: rawRuntime))
  }

  package static func makeStringValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeString(value, in: rawContext))
  }

  package static func makeNumberValueHandle(
    _ value: Double,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeNumber(value, in: rawContext))
  }

  package static func makeSymbolValueHandle(
    _ value: String,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeSymbol(value, in: rawContext))
  }

  package static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeBoolean(value, in: rawContext))
  }

  package static func makeNullValueHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeNull(in: rawContext))
  }

  package static func makeUndefinedValueHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSValueHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return JSValueHandle<Engine>(_opaqueHandle: makeUndefined(in: rawContext))
  }

  package static func makeObjectResultHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return _resultHandle(from: makeObject(in: rawContext))
  }

  package static func makeArrayResultHandle(
    _ context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return _resultHandle(from: makeArray(in: rawContext))
  }

  package static func evaluateScriptResultHandle(
    _ script: String,
    _ context: JSBorrowedContextHandle<Engine>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle() else {
      return nil
    }
    return _resultHandle(
      from: evaluateScript(
        script,
        in: rawContext,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }
}
