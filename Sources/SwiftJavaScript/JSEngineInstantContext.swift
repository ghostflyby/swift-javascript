/// Engine-agnostic instant context shell.
///
/// Concrete engines provide API surface and bridge behaviors in facade
/// modules via constrained extensions.
public struct JSEngineInstantContext<E: JSEngine>: ~Copyable {
  public let driverContextHandle: E.ContextHandle

  package init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
  }
}

extension JSEngineInstantContext {
  @inline(__always)
  private func valueFromHandle(
    _ handle: JSValueHandle<E>?,
    _ failureMessage: StaticString
  ) -> JSEngineValue<E> {
    guard let handle else {
      preconditionFailure(String(describing: failureMessage))
    }
    return JSEngineValue(handleValue: handle)
  }

  @inline(__always)
  private func valueFromResultHandle(
    _ handleResult: JSResultPayload<JSValueHandle<E>>?
  ) -> JSEngineValue<E> {
    let result: JSResultPayload<JSEngineValue<E>> = bridgeHandleResult(handleResult)
    switch consume result {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  public func makeString(_ value: String) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeStringValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeString could not create handle"
    )
  }

  package func makeSymbol(_ value: String) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeSymbolValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeSymbol could not create handle"
    )
  }

  public func makeNumber(_ value: Double) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeNumberValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeNumber could not create handle"
    )
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSEngineValue<E> {
    makeNumber(Double(value))
  }

  public func makeBoolean(_ value: Bool) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeBooleanValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeBoolean could not create handle"
    )
  }

  public func makeNull() -> JSEngineValue<E> {
    valueFromHandle(
      E.makeNullValueHandle(driverContextHandle),
      "JSEngineInstantContext.makeNull could not create handle"
    )
  }

  public func makeUndefined() -> JSEngineValue<E> {
    valueFromHandle(
      E.makeUndefinedValueHandle(driverContextHandle),
      "JSEngineInstantContext.makeUndefined could not create handle"
    )
  }

  public func makeObject() -> JSEngineValue<E> {
    valueFromResultHandle(E.makeObjectResultHandle(driverContextHandle))
  }

  public func makeArray() -> JSEngineValue<E> {
    valueFromResultHandle(E.makeArrayResultHandle(driverContextHandle))
  }

  public func evaluateScript(_ script: String) -> JSResultPayload<JSEngineValue<E>> {
    bridgeHandleResult(
      E.evaluateScriptResultHandle(
        script,
        driverContextHandle,
        sourceURL: nil,
        startingLineNumber: 1
      ))
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResultPayload<JSEngineValue<E>> {
    bridgeHandleResult(
      E.evaluateScriptResultHandle(
        script,
        driverContextHandle,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ))
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResultPayload<JSEngineValue<E>> where Script: JSString, Script: ~Copyable {
    bridgeHandleResult(
      E.evaluateScriptResultHandle(
        script.string,
        driverContextHandle,
        sourceURL: nil,
        startingLineNumber: startingLineNumber
      ))
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResultPayload<JSEngineValue<E>> where Script: JSString, Script: ~Copyable {
    evaluateScript(script.string, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResultPayload<JSEngineValue<E>> where SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(script, sourceURL: sourceURL.string, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResultPayload<JSEngineValue<E>>
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(
      script.string,
      sourceURL: sourceURL.string,
      startingLineNumber: startingLineNumber
    )
  }

  public func toBoolean(_ value: borrowing JSEngineValue<E>) -> Bool {
    E.toBooleanForHandle(value.valueHandle(), in: driverContextHandle)
  }

  public func toNumber(_ value: borrowing JSEngineValue<E>) -> Double {
    E.toNumberForHandle(value.valueHandle(), in: driverContextHandle)
  }

  public func toString(_ value: borrowing JSEngineValue<E>) -> String {
    E.toStringForHandle(value.valueHandle(), in: driverContextHandle) ?? ""
  }
}
