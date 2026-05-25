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
    return JSValue(handleValue: handle, in: driverContextHandle)
  }

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type = K.self) {
    E.contextDataStorageBox(in: driverContextHandle)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type = K.self) -> K.Value? {
    E.contextDataStorageBox(in: driverContextHandle)?.data(for: key) ?? K.defaultValue
  }

  @inline(__always)
  private func valueFromResultHandle(
    _ handleResult: JSResult<JSValueHandle<E>>?,
    in context: E.ContextHandle
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(handleResult, in: context)
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

  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSValue<E> {
    valueFromHandle(
      E.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: self),
        in: driverContextHandle
      ),
      "JSInstantContext.makeString(from:) could not create handle"
    )
  }

  public func makePropertyStringKey(_ value: String) -> JSPropertyStringKey<E> {
    guard let handle = E.makePropertyStringKeyHandle(value, in: driverContextHandle) else {
      preconditionFailure("JSInstantContext.makePropertyStringKey could not create handle")
    }
    return JSPropertyStringKey(handle: handle, context: driverContextHandle)
  }

  public func prepareScript(_ source: String) -> JSPreparedScript<E> {
    guard let handle = E.makePreparedScriptHandle(source, in: driverContextHandle) else {
      preconditionFailure("JSInstantContext.prepareScript could not create handle")
    }
    return JSPreparedScript(handle: handle, context: driverContextHandle)
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
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withGlobalObject { globalObject in
      globalObject.setProperty(value, forKey: key, with: attributes, in: self)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    withGlobalObject { globalObject in
      globalObject.setProperty(value, forKey: key, using: converter, with: attributes, in: self)
    }
  }

  public func getGlobalProperty(forKey key: StaticString) -> JSValue<E> {
    withGlobalObject { globalObject in
      globalObject.getProperty(forKey: key, in: self)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type
  ) -> C.SwiftType {
    withGlobalObject { globalObject in
      globalObject.getProperty(forKey: key, using: converter, in: self)
    }
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    withGlobalObject { globalObject in
      globalObject.deleteProperty(forKey: key, in: self)
    }
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    withGlobalObject { globalObject in
      globalObject.hasProperty(key, in: self)
    }
  }

  public func makeObject() -> JSValue<E> {
    valueFromResultHandle(E.makeObjectResultHandle(driverContextHandle), in: driverContextHandle)
  }

  public func makeArray() -> JSValue<E> {
    valueFromResultHandle(E.makeArrayResultHandle(driverContextHandle), in: driverContextHandle)
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
    let key = makePropertyStringKey(name)
    withGlobalObject { globalObject in
      globalObject.setProperty(function, forKey: key, with: attributes, in: self)
    }
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    let preparedScript = prepareScript(script)
    return evaluateScript(
      preparedScript,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  public func evaluateScript(
    _ script: borrowing JSPreparedScript<E>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      E.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: self),
        driverContextHandle,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ), in: driverContextHandle
    )
  }

  public func toBoolean(_ value: borrowing JSValue<E>) -> Bool {
    E.toBooleanForHandle(value.borrowHandle(), in: driverContextHandle)
  }

  public func toNumber(_ value: borrowing JSValue<E>) -> Double {
    E.toNumberForHandle(value.borrowHandle(), in: driverContextHandle)
  }

  public func toString(_ value: borrowing JSValue<E>) -> String {
    E.toStringForHandle(value.borrowHandle(), in: driverContextHandle) ?? ""
  }
}

// MARK: - Callback scope operations

extension JSInstantContext {
  /// Upgrade a temporary callback value to a persistent JSValue.
  public func persist(_ value: borrowing JSCallbackValue<E>) -> JSValue<E> {
    guard let frame = TLSCallbackStack.top,
      frame.engineTypeID == ObjectIdentifier(E.self),
      frame.contextBox is E.ContextHandle
    else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    value.handle.retainReference(in: self.driverContextHandle)
    return JSValue(handleValue: value.handle, in: self.driverContextHandle)
  }

  /// Wrap a temporary value as a callback return value (borrowed handle).
  public func `return`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    guard let frame = TLSCallbackStack.top,
      frame.engineTypeID == ObjectIdentifier(E.self),
      frame.contextBox is E.ContextHandle
    else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    return JSCallbackReturn(temporary: value.handle)
  }

  /// Wrap a persistent JSValue as a callback return value (owned).
  public func `return`(_ value: consuming JSValue<E>) -> JSCallbackReturn<E> {
    guard TLSCallbackStack.top != nil else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    return JSCallbackReturn(persistent: value)
  }

  /// Mark a JS exception return value (borrowed temporary handle).
  public func `throw`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    guard let frame = TLSCallbackStack.top,
      frame.engineTypeID == ObjectIdentifier(E.self),
      frame.contextBox is E.ContextHandle
    else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    return JSCallbackReturn(exception: value.handle)
  }

  /// Mark a JS exception return value (owned persistent JSValue).
  public func `throw`(_ value: consuming JSValue<E>) -> JSCallbackReturn<E> {
    guard TLSCallbackStack.top != nil else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    return JSCallbackReturn(exception: value.takeHandle())
  }

  /// Return an undefined value (convenience).
  public func returnUndefined() -> JSCallbackReturn<E> {
    guard TLSCallbackStack.top != nil else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    return JSCallbackReturn(temporary: makeUndefined().handle)
  }

  /// Throw an undefined exception (convenience).
  public func throwUndefined() -> JSCallbackReturn<E> {
    guard TLSCallbackStack.top != nil else {
      preconditionFailure("Scope operation called outside an active callback scope")
    }
    return JSCallbackReturn(exception: makeUndefined().handle)
  }
}

// MARK: - Internal TLS scope lookup
