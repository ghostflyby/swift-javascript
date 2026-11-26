import SwiftJavaScript

// MARK: - QuickJS scopes
//
// Both scopes hold the shared `ScopeCore<QJSContextHandle, JSImplicitStackRoots>`:
// push/pop and arena settlement stay in core; the operations that create and
// adopt values (factories, global reads, script results, function/key/script
// construction, context data) are implemented here, on this scope's arena.
// What stays in core is the value-level composition that never adopts (the
// installed-function wrapper, the callback-value global write). QuickJS touches
// its stack top from the value handle's `ref` accessor (`JS_UpdateStackTop`),
// so the scope itself never needs a separate update call.

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct QJSInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = QJSContext
  package typealias ContextHandle = QJSContextHandle
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
  public typealias CallbackReturn = QJSCallbackReturn
  public typealias CallbackArguments = QJSCallbackArguments
  public typealias Arguments = QJSArguments
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: ScopeCore<QJSContextHandle, JSImplicitStackRoots>

  package var driverContextHandle: QJSContextHandle { core.driverContextHandle }

  package init(handle: QJSContextHandle) {
    self.core = ScopeCore(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<QJSContextHandle>.pop(for: core.driverContextHandle)
  }

  // MARK: - Ledger primitives

  package func adoptCreatedHandle(_ handle: consuming QJSOwnedValueHandle) -> QJSValue {
    QJSValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func adoptCallbackHandle(
    _ handle: consuming QJSOwnedValueHandle
  ) -> QJSCallbackValue {
    QJSCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func anchorBorrowedHandle(_ handle: QJSValueHandle) -> QJSValue {
    QJSValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing QJSCallbackValue) -> QJSValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return QJSValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing QJSCallbackValue) -> QJSValue {
    QJSValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSCallbackValue {
    let contextHandle = core.driverContextHandle
    guard
      let handle = contextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: contextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNumber(_ value: Double) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<QJSCallbackValue> {
    guard let result = core.driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  public func makeArray() -> JSResult<QJSCallbackValue> {
    guard let result = core.driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing QJSInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    try body(self)
  }

  // MARK: - Callback exit

  public func `return`(_ value: borrowing QJSCallbackValue) -> QJSCallbackReturn {
    QJSCallbackReturn(temporary: value.borrowHandle())
  }

  public func `return`(_ value: borrowing QJSValue) -> QJSCallbackReturn {
    QJSCallbackReturn(temporary: value.borrowHandle())
  }

  public func `throw`(_ value: borrowing QJSCallbackValue) -> QJSCallbackReturn {
    QJSCallbackReturn(exception: value.borrowHandle())
  }

  public func `throw`(_ value: borrowing QJSValue) -> QJSCallbackReturn {
    QJSCallbackReturn(exception: value.borrowHandle())
  }

  public func returnUndefined() -> QJSCallbackReturn {
    QJSCallbackReturn(temporary: makeUndefined().borrowHandle())
  }

  public func throwUndefined() -> QJSCallbackReturn {
    QJSCallbackReturn(exception: makeUndefined().borrowHandle())
  }

  // MARK: - Global object

  public func globalObjectValue() -> QJSValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSInstantContext.globalObjectValue could not get global object")
    }
    return QJSValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    let contextHandle = core.driverContextHandle
    guard let global = contextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSInstantContext.getGlobalProperty could not get global object")
    }
    guard let result = contextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("QJSInstantContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      contextHandle.releaseCreatedHandle(QJSOwnedValueHandle.adopting(handle))
      guard let undefined = contextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("QJSInstantContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing QJSValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.deleteStaticStringPropertyHandle(key, on: global)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else {
      return false
    }
    return core.driverContextHandle.hasStaticStringPropertyHandle(key, on: global) ?? false
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let handle = core.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    let borrowed = handle.borrowed()
    core.trackOnDefaultFrame(handle)
    return QJSValue(handle: borrowed, contextHandle: core.driverContextHandle)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing QJSCallbackValue
  ) -> QJSPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(_ value: borrowing QJSValue) -> QJSPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func resolve(_ handle: QJSPersistentHandle) -> QJSValue? {
    resolvePersistentHandle(handle.identity, in: self)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> QJSPropertyStringKey {
    guard let handle = core.driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return QJSPropertyStringKey(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<QJSContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    guard let handle = core.driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return QJSPreparedScript(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<QJSContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }
  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let contextHandle = core.driverContextHandle
    guard
      let result = contextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: contextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("QJSInstantContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    core.driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    core.driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
}

extension QJSInstantContext: JSScopeWitness {
  package var scopeFrame: ScopeFrame<QJSContextHandle> { core.frame }

  package func makeValue(handle: QJSValueHandle) -> QJSValue {
    QJSValue(handle: handle, contextHandle: core.driverContextHandle)
  }
}

/// The manual QuickJS scope (`JSContext`-derived construction).
public struct QJSScope: SwiftJavaScript.JSScope, ~Copyable, ~Sendable {
  public typealias Context = QJSContext
  package typealias ContextHandle = QJSContextHandle
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias InstantContext = QJSInstantContext
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: ScopeCore<QJSContextHandle, JSImplicitStackRoots>
  private var isOpen = false

  package var driverContextHandle: QJSContextHandle { core.driverContextHandle }

  package init(handle: QJSContextHandle) {
    self.core = ScopeCore(handle: handle)
  }

  /// Push the context scope stack and begin arena tracking. Idempotent.
  @available(*, noasync)
  package mutating func open() {
    guard !isOpen else { return }
    ScopeStackRegistry.push(core, for: core.driverContextHandle)
    isOpen = true
  }

  deinit {
    core.drain()
    if isOpen { ScopeStackRegistry<QJSContextHandle>.pop(for: core.driverContextHandle) }
  }

  // MARK: - Ledger primitives

  package func adoptCreatedHandle(_ handle: consuming QJSOwnedValueHandle) -> QJSValue {
    QJSValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func adoptCallbackHandle(
    _ handle: consuming QJSOwnedValueHandle
  ) -> QJSCallbackValue {
    QJSCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func anchorBorrowedHandle(_ handle: QJSValueHandle) -> QJSValue {
    QJSValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing QJSCallbackValue) -> QJSValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return QJSValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing QJSCallbackValue) -> QJSValue {
    QJSValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSCallbackValue {
    let contextHandle = core.driverContextHandle
    guard
      let handle = contextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: contextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNumber(_ value: Double) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> QJSCallbackValue {
    guard let handle = core.driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<QJSCallbackValue> {
    guard let result = core.driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  public func makeArray() -> JSResult<QJSCallbackValue> {
    guard let result = core.driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing QJSInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let window = QJSInstantContext(handle: core.driverContextHandle)
    return try body(window)
  }

  // MARK: - Global object

  public func globalObjectValue() -> QJSValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSScope.globalObjectValue could not get global object")
    }
    return QJSValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    let contextHandle = core.driverContextHandle
    guard let global = contextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSScope.getGlobalProperty could not get global object")
    }
    guard let result = contextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("QJSScope.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      contextHandle.releaseCreatedHandle(QJSOwnedValueHandle.adopting(handle))
      guard let undefined = contextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("QJSScope could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing QJSValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.deleteStaticStringPropertyHandle(key, on: global)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else {
      return false
    }
    return core.driverContextHandle.hasStaticStringPropertyHandle(key, on: global) ?? false
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let handle = core.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    let borrowed = handle.borrowed()
    core.trackOnDefaultFrame(handle)
    return QJSValue(handle: borrowed, contextHandle: core.driverContextHandle)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing QJSCallbackValue
  ) -> QJSPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(_ value: borrowing QJSValue) -> QJSPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func resolve(_ handle: QJSPersistentHandle) -> QJSValue? {
    resolvePersistentHandle(handle.identity, in: self)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> QJSPropertyStringKey {
    guard let handle = core.driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return QJSPropertyStringKey(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<QJSContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    guard let handle = core.driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return QJSPreparedScript(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<QJSContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }
  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let contextHandle = core.driverContextHandle
    guard
      let result = contextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: contextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("QJSScope.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    core.driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    core.driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
}

extension QJSScope: JSScopeWitness {
  package var scopeFrame: ScopeFrame<QJSContextHandle> { core.frame }

  package func makeValue(handle: QJSValueHandle) -> QJSValue {
    QJSValue(handle: handle, contextHandle: core.driverContextHandle)
  }
}

// MARK: - Persistent binding minting
//
// Both scopes mint the same way: through the context's registry, which only a
// hosted `QJSContext` installs (a raw callback context has no data box).

/// Mint a persistent binding for `handle`, addressed through `contextHandle`.
@available(*, noasync)
private func mintPersistentHandle(
  _ handle: QJSValueHandle,
  of contextHandle: QJSContextHandle,
  on core: borrowing ScopeCore<QJSContextHandle, JSImplicitStackRoots>
) -> QJSPersistentHandle {
  precondition(
    contextHandle == core.driverContextHandle,
    "JSPersistentHandle can only be minted for values of its own context"
  )
  guard
    let registry = JSPersistentHandleRegistry<QJSContextHandle>.registry(
      for: core.driverContextHandle)
  else {
    preconditionFailure(
      "JSPersistentHandle minting requires a hosted JSContext (no registry installed)"
    )
  }
  return QJSPersistentHandle(identity: registry.mintIdentity(handle), registry: registry)
}
