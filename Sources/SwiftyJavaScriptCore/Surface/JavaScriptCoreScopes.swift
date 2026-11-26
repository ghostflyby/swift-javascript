import SwiftJavaScript

// MARK: - JavaScriptCore scopes
//
// Both scopes hold the shared `ScopeCore<JSCContextHandle, JSImplicitStackRoots>`:
// push/pop and arena settlement stay in core; the operations that create and
// adopt values (factories, global reads, script results, function/key/script
// construction, context data) are implemented here, on this scope's arena.
// What stays in core is the value-level composition that never adopts (the
// installed-function wrapper, the callback-value global write).

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct JSCInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = JSCContext
  package typealias ContextHandle = JSCContextHandle
  public typealias Value = JSCValue
  public typealias CallbackValue = JSCCallbackValue
  public typealias CallbackReturn = JSCCallbackReturn
  public typealias CallbackArguments = JSCCallbackArguments
  public typealias Arguments = JSCArguments
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias PreparedScript = JSCPreparedScript
  public typealias PersistentHandle = JSCPersistentHandle

  private var core: ScopeCore<JSCContextHandle, JSImplicitStackRoots>

  package var driverContextHandle: JSCContextHandle { core.driverContextHandle }

  package init(handle: JSCContextHandle) {
    self.core = ScopeCore(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<JSCContextHandle>.pop(for: core.driverContextHandle)
  }

  // MARK: - Ledger primitives

  package func adoptCreatedHandle(_ handle: consuming JSCOwnedValueHandle) -> JSCValue {
    JSCValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func adoptCallbackHandle(
    _ handle: consuming JSCOwnedValueHandle
  ) -> JSCCallbackValue {
    JSCCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func anchorBorrowedHandle(_ handle: JSCValueHandle) -> JSCValue {
    JSCValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCCallbackValue) -> JSCValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return JSCValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing JSCCallbackValue) -> JSCValue {
    JSCValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(from key: borrowing JSCPropertyStringKey) -> JSCCallbackValue {
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

  public func makeNumber(_ value: Double) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<JSCCallbackValue> {
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

  public func makeArray() -> JSResult<JSCCallbackValue> {
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
    _ body: (borrowing JSCInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    try body(self)
  }

  // MARK: - Callback exit

  public func `return`(_ value: borrowing JSCCallbackValue) -> JSCCallbackReturn {
    JSCCallbackReturn(temporary: value.borrowHandle())
  }

  public func `return`(_ value: borrowing JSCValue) -> JSCCallbackReturn {
    JSCCallbackReturn(temporary: value.borrowHandle())
  }

  public func `throw`(_ value: borrowing JSCCallbackValue) -> JSCCallbackReturn {
    JSCCallbackReturn(exception: value.borrowHandle())
  }

  public func `throw`(_ value: borrowing JSCValue) -> JSCCallbackReturn {
    JSCCallbackReturn(exception: value.borrowHandle())
  }

  public func returnUndefined() -> JSCCallbackReturn {
    JSCCallbackReturn(temporary: makeUndefined().borrowHandle())
  }

  public func throwUndefined() -> JSCCallbackReturn {
    JSCCallbackReturn(exception: makeUndefined().borrowHandle())
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCInstantContext.globalObjectValue could not get global object")
    }
    return JSCValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func getGlobalProperty(forKey key: StaticString) -> JSCValue {
    let contextHandle = core.driverContextHandle
    guard let global = contextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCInstantContext.getGlobalProperty could not get global object")
    }
    guard let result = contextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("JSCInstantContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      contextHandle.releaseCreatedHandle(JSCOwnedValueHandle.adopting(handle))
      guard let undefined = contextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("JSCInstantContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing JSCValue,
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
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCValue {
    guard
      let handle = core.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    let borrowed = handle.borrowed()
    core.trackOnDefaultFrame(handle)
    return JSCValue(handle: borrowed, contextHandle: core.driverContextHandle)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing JSCCallbackValue
  ) -> JSCPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(_ value: borrowing JSCValue) -> JSCPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func resolve(_ handle: JSCPersistentHandle) -> JSCValue? {
    resolvePersistentHandle(handle.identity, in: self)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> JSCPropertyStringKey {
    guard let handle = core.driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return JSCPropertyStringKey(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<JSCContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let handle = core.driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return JSCPreparedScript(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<JSCContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }
  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing JSCPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValue> {
    let contextHandle = core.driverContextHandle
    guard
      let result = contextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: contextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSCInstantContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
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

extension JSCInstantContext: JSScopeWitness {
  package var scopeFrame: ScopeFrame<JSCContextHandle> { core.frame }

  package func makeValue(handle: JSCValueHandle) -> JSCValue {
    JSCValue(handle: handle, contextHandle: core.driverContextHandle)
  }
}

/// The manual JavaScriptCore scope (`JSContext`-derived construction).
public struct JSCScope: SwiftJavaScript.JSScope, ~Copyable, ~Sendable {
  public typealias Context = JSCContext
  package typealias ContextHandle = JSCContextHandle
  public typealias Value = JSCValue
  public typealias CallbackValue = JSCCallbackValue
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias InstantContext = JSCInstantContext
  public typealias PreparedScript = JSCPreparedScript
  public typealias PersistentHandle = JSCPersistentHandle

  private var core: ScopeCore<JSCContextHandle, JSImplicitStackRoots>
  private var isOpen = false

  package var driverContextHandle: JSCContextHandle { core.driverContextHandle }

  package init(handle: JSCContextHandle) {
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
    if isOpen { ScopeStackRegistry<JSCContextHandle>.pop(for: core.driverContextHandle) }
  }

  // MARK: - Ledger primitives

  package func adoptCreatedHandle(_ handle: consuming JSCOwnedValueHandle) -> JSCValue {
    JSCValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func adoptCallbackHandle(
    _ handle: consuming JSCOwnedValueHandle
  ) -> JSCCallbackValue {
    JSCCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  package func anchorBorrowedHandle(_ handle: JSCValueHandle) -> JSCValue {
    JSCValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCCallbackValue) -> JSCValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return JSCValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing JSCCallbackValue) -> JSCValue {
    JSCValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(from key: borrowing JSCPropertyStringKey) -> JSCCallbackValue {
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

  public func makeNumber(_ value: Double) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> JSCCallbackValue {
    guard let handle = core.driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<JSCCallbackValue> {
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

  public func makeArray() -> JSResult<JSCCallbackValue> {
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
    _ body: (borrowing JSCInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let window = JSCInstantContext(handle: core.driverContextHandle)
    return try body(window)
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCScope.globalObjectValue could not get global object")
    }
    return JSCValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func getGlobalProperty(forKey key: StaticString) -> JSCValue {
    let contextHandle = core.driverContextHandle
    guard let global = contextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCScope.getGlobalProperty could not get global object")
    }
    guard let result = contextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("JSCScope.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      contextHandle.releaseCreatedHandle(JSCOwnedValueHandle.adopting(handle))
      guard let undefined = contextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("JSCScope could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing JSCValue,
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
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCValue {
    guard
      let handle = core.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    let borrowed = handle.borrowed()
    core.trackOnDefaultFrame(handle)
    return JSCValue(handle: borrowed, contextHandle: core.driverContextHandle)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing JSCCallbackValue
  ) -> JSCPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(_ value: borrowing JSCValue) -> JSCPersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func resolve(_ handle: JSCPersistentHandle) -> JSCValue? {
    resolvePersistentHandle(handle.identity, in: self)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> JSCPropertyStringKey {
    guard let handle = core.driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return JSCPropertyStringKey(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<JSCContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let handle = core.driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return JSCPreparedScript(
      handle: handle,
      contextHandle: core.driverContextHandle,
      vmThread: ScopeStackRegistry<JSCContextHandle>.vmThread(for: core.driverContextHandle)
    )
  }
  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing JSCPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValue> {
    let contextHandle = core.driverContextHandle
    guard
      let result = contextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: contextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSCScope.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
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

extension JSCScope: JSScopeWitness {
  package var scopeFrame: ScopeFrame<JSCContextHandle> { core.frame }

  package func makeValue(handle: JSCValueHandle) -> JSCValue {
    JSCValue(handle: handle, contextHandle: core.driverContextHandle)
  }
}

// MARK: - Persistent binding minting
//
// Both scopes mint the same way: through the context's registry, which only a
// hosted `JSCContext` installs (a raw callback context has no data box).

/// Mint a persistent binding for `handle`, addressed through `contextHandle`.
@available(*, noasync)
private func mintPersistentHandle(
  _ handle: JSCValueHandle,
  of contextHandle: JSCContextHandle,
  on core: borrowing ScopeCore<JSCContextHandle, JSImplicitStackRoots>
) -> JSCPersistentHandle {
  precondition(
    contextHandle == core.driverContextHandle,
    "JSPersistentHandle can only be minted for values of its own context"
  )
  guard
    let registry = JSPersistentHandleRegistry<JSCContextHandle>.registry(
      for: core.driverContextHandle)
  else {
    preconditionFailure(
      "JSPersistentHandle minting requires a hosted JSContext (no registry installed)"
    )
  }
  return JSCPersistentHandle(
    identity: registry.mintIdentity(handle), registry: registry)
}
