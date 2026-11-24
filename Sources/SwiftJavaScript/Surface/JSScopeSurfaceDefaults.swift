// MARK: - Surface scope defaults
//
// Shared implementations for the surface scope protocols, written for
// `~Copyable` conformers (`where Self: ~Copyable`). They are built only on the
// protocols' own requirements: the ledger primitives
// (`adoptCreatedHandle`/`adoptCallbackHandle`) and the context handle's driver
// operations. Wrapping a handle in an engine view is the one step each engine
// keeps to itself, inside those ledger primitives.

extension JSValueScope where Self: ~Copyable {
  // MARK: Value factories

  public func makeString(_ value: String) -> CallbackValue {
    guard let handle = driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(from key: borrowing PropertyStringKey) -> CallbackValue {
    guard
      let handle = driverContextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: driverContextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNumber(_ value: Double) -> CallbackValue {
    guard let handle = driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> CallbackValue {
    guard let handle = driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> CallbackValue {
    guard let handle = driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> CallbackValue {
    guard let handle = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> CallbackValue {
    guard let handle = driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<CallbackValue> {
    guard let result = driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    return adoptCallbackResult(result)
  }

  public func makeArray() -> JSResult<CallbackValue> {
    guard let result = driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    return adoptCallbackResult(result)
  }

  /// Track both branches of an engine result (value or exception) exactly once.
  private func adoptCallbackResult(
    _ result: consuming JSResult<ContextHandle.OwnedValueHandle>
  ) -> JSResult<CallbackValue> {
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  // MARK: Global object

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> Value {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSValueScope.getGlobalProperty could not get global object")
    }
    guard
      let result = driverContextHandle.getStaticStringPropertyHandle(key, on: global)
    else {
      preconditionFailure("JSValueScope.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle))
    case .exception(let handle):
      driverContextHandle.releaseCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle))
      guard let undefined = driverContextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("JSValueScope could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing Value,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
  ) {
    guard let global = driverContextHandle.globalObjectValueHandle() else { return }
    _ = driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  /// Write a value created in this window without an explicit `persist`; the
  /// window's arena keeps it alive at least until its drain.
  public func setGlobalProperty(
    _ value: borrowing CallbackValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
  ) {
    guard let global = driverContextHandle.globalObjectValueHandle() else { return }
    _ = driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = driverContextHandle.globalObjectValueHandle() else { return }
    _ = driverContextHandle.deleteStaticStringPropertyHandle(key, on: global)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      return false
    }
    return driverContextHandle.hasStaticStringPropertyHandle(key, on: global) ?? false
  }

  // MARK: Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type = K.self) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
}

extension JSInstantContext where Self: ~Copyable {
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing Value) -> R
  ) -> R {
    body(globalObjectValue())
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes = .none,
    callback: @escaping JSFunctionCallback<Self>
  ) {
    let function = makeFunction(named: name, callback: callback)
    guard
      let keyHandle = driverContextHandle.makePropertyStringKeyHandle(name),
      let global = driverContextHandle.globalObjectValueHandle()
    else { return }
    defer { _ = keyHandle.releaseReference() }
    _ = driverContextHandle.setPropertyStringKeyHandle(
      keyHandle,
      on: global,
      to: function.borrowHandle(),
      attributes: attributes
    )
  }

  // MARK: Scripts

  public func evaluateScript(
    _ script: borrowing PreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<Value> {
    guard
      let result = driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSInstantContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle)))
    }
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<Value> {
    evaluateScript(
      prepareScript(script),
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  // MARK: Encoder-based global writes

  public func setGlobalProperty<Value_: JSValueEncodable & ~Copyable>(
    _ value: borrowing Value_,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
  ) {
    let encoded = value.toSurfaceValue(in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSHostMemberAttributes = .none
  ) {
    _ = converter
    let encoded = C.encode(value, in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }
}

extension JSScope where Self: ~Copyable {
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing Value) -> R
  ) -> R {
    body(globalObjectValue())
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes = .none,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) {
    let function = makeFunction(named: name, callback: callback)
    guard
      let keyHandle = driverContextHandle.makePropertyStringKeyHandle(name),
      let global = driverContextHandle.globalObjectValueHandle()
    else { return }
    defer { _ = keyHandle.releaseReference() }
    _ = driverContextHandle.setPropertyStringKeyHandle(
      keyHandle,
      on: global,
      to: function.borrowHandle(),
      attributes: attributes
    )
  }

  // MARK: Scripts

  public func evaluateScript(
    _ script: borrowing PreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<Value> {
    guard
      let result = driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSScope.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle)))
    }
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<Value> {
    evaluateScript(
      prepareScript(script),
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  // MARK: Encoder-based global writes

  public func setGlobalProperty<Value_: JSValueEncodable & ~Copyable>(
    _ value: borrowing Value_,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
  ) {
    let encoded = value.toSurfaceValue(in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSHostMemberAttributes = .none
  ) {
    _ = converter
    let encoded = C.encode(value, in: self)
    setGlobalProperty(encoded, forKey: key, with: attributes)
  }
}
