/// A lightweight callback-facing context used for synchronous JavaScript interactions.
///
/// `JSInstantContext` mirrors the user-facing API surface of `JSContext` for callback code,
/// but avoids actor hops so callbacks can run in a tight synchronous path.
///
/// Design intent:
/// - Provide a lightweight substitute for `JSContext` inside callback-heavy code paths.
/// - Keep API semantics aligned with `JSContext` (`make*`, global property helpers,
///   `evaluateScript`, etc.).
///
/// Non-goals:
/// - It is not a generic low-level bridge layer.
/// - Backend/handle/raw-context orchestration should stay in backend adapters or
///   local call-site helpers unless it is part of this callback-facing API surface.
public struct JSInstantContext<E: JSEngine>: ~Copyable {
  public let driverContextHandle: E.ContextHandle

  package init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
  }
}

extension JSInstantContext {
  @inline(__always)
  private func valueFromHandle(
    _ handle: JSValueHandle<E>?,
    _ failureMessage: StaticString
  ) -> JSValue<E> {
    guard let handle else {
      preconditionFailure(String(describing: failureMessage))
    }
    return JSValue(handleValue: handle)
  }

  @inline(__always)
  private func valueFromResultHandle(
    _ handleResult: JSResult<JSValueHandle<E>>?
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(handleResult)
    switch consume result {
    case .value(let value):
      return value
    case .exception(let exception):
      return exception
    }
  }

  public func makeString(_ value: String) -> JSValue<E> {
    valueFromHandle(
      E.makeStringValueHandle(value, driverContextHandle),
      "JSInstantContext.makeString could not create handle"
    )
  }

  func makeSymbol(_ value: String) -> JSValue<E> {
    valueFromHandle(
      E.makeSymbolValueHandle(value, driverContextHandle),
      "JSInstantContext.makeSymbol could not create handle"
    )
  }

  public func makeNumber(_ value: Double) -> JSValue<E> {
    valueFromHandle(
      E.makeNumberValueHandle(value, driverContextHandle),
      "JSInstantContext.makeNumber could not create handle"
    )
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSValue<E> {
    makeNumber(Double(value))
  }

  public func makeBoolean(_ value: Bool) -> JSValue<E> {
    valueFromHandle(
      E.makeBooleanValueHandle(value, driverContextHandle),
      "JSInstantContext.makeBoolean could not create handle"
    )
  }

  public func makeNull() -> JSValue<E> {
    valueFromHandle(
      E.makeNullValueHandle(driverContextHandle),
      "JSInstantContext.makeNull could not create handle"
    )
  }

  public func makeUndefined() -> JSValue<E> {
    valueFromHandle(
      E.makeUndefinedValueHandle(driverContextHandle),
      "JSInstantContext.makeUndefined could not create handle"
    )
  }

  @inline(__always)
  private func globalObjectValue() -> JSValue<E> {
    valueFromHandle(
      E.globalObjectValueHandle(driverContextHandle),
      "JSInstantContext.globalObjectValue could not create handle"
    )
  }

  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    let globalObject = globalObjectValue()
    return body(globalObject)
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withGlobalObject { globalObject in
      globalObject.setProperty(value, forKey: key, with: attributes, in: self)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    withGlobalObject { globalObject in
      globalObject.setProperty(value, forKey: key, using: converter, with: attributes, in: self)
    }
  }

  public func getGlobalProperty(forKey key: String) -> JSValue<E> {
    withGlobalObject { globalObject in
      globalObject.getProperty(forKey: key, in: self)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type
  ) -> C.SwiftType {
    withGlobalObject { globalObject in
      globalObject.getProperty(forKey: key, using: converter, in: self)
    }
  }

  public func deleteGlobalProperty(forKey key: String) {
    withGlobalObject { globalObject in
      globalObject.deleteProperty(forKey: key, in: self)
    }
  }

  public func hasGlobalProperty(_ key: String) -> Bool {
    withGlobalObject { globalObject in
      globalObject.hasProperty(key, in: self)
    }
  }

  public func makeObject() -> JSValue<E> {
    valueFromResultHandle(E.makeObjectResultHandle(driverContextHandle))
  }

  public func makeArray() -> JSValue<E> {
    valueFromResultHandle(E.makeArrayResultHandle(driverContextHandle))
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    valueFromHandle(
      E.makeFunctionValueHandle(
        named: name,
        callback: callback,
        in: driverContextHandle
      ),
      "JSInstantContext.makeFunction could not create handle"
    )
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback<E>
  ) where E.Engine == E {
    let function = makeFunction(named: name, callback: callback)
    withGlobalObject { globalObject in
      globalObject.setProperty(function, forKey: name, with: attributes, in: self)
    }
  }

  public func evaluateScript(_ script: String) -> JSResult<JSValue<E>> {
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
  ) -> JSResult<JSValue<E>> {
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
  ) -> JSResult<JSValue<E>> where Script: JSString, Script: ~Copyable {
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
  ) -> JSResult<JSValue<E>> where Script: JSString, Script: ~Copyable {
    evaluateScript(script.string, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(script, sourceURL: sourceURL.string, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>>
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(
      script.string,
      sourceURL: sourceURL.string,
      startingLineNumber: startingLineNumber
    )
  }

  public func toBoolean(_ value: borrowing JSValue<E>) -> Bool {
    E.toBooleanForHandle(value.valueHandle(), in: driverContextHandle)
  }

  public func toNumber(_ value: borrowing JSValue<E>) -> Double {
    E.toNumberForHandle(value.valueHandle(), in: driverContextHandle)
  }

  public func toString(_ value: borrowing JSValue<E>) -> String {
    E.toStringForHandle(value.valueHandle(), in: driverContextHandle) ?? ""
  }
}
