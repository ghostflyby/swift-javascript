import JavaScriptCore
import SwiftJavaScript

// MARK: - JavaScriptCore scopes
//
// Both scopes own one concrete `JSCScopeCore`: a frame of raw `JSValueRef`s
// with JSC's protect/unprotect rooting policy. Synchronous windows use
// implicit stack roots; the context default frame uses explicit roots.

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct JSCInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = JSCContext
  public typealias Value = JSCValue
  public typealias CallbackReturn = JSCCallbackReturn
  public typealias CallbackArguments = JSCCallbackArguments
  public typealias Arguments = JSCArguments
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias PreparedScript = JSCPreparedScript
  public typealias PersistentHandle = JSCPersistentHandle

  private var core: JSCScopeCore

  package var contextRef: JSGlobalContextRef { core.contextRef }

  package init(contextRef: JSGlobalContextRef) {
    self.core = JSCScopeCore(contextRef: contextRef, rootsArenaValues: false)
    JSCScopeStacks.push(core)
  }

  deinit {
    core.drain()
    JSCScopeStacks.pop(for: core.contextRef)
  }

  // MARK: - Ledger primitives

  package func adoptCreatedHandle(_ ref: JSValueRef) -> JSCValue {
    JSCValue(ref: core.trackCreatedHandle(ref), contextRef: core.contextRef)
  }

  package func anchorBorrowedHandle(_ ref: JSValueRef) -> JSCValue {
    JSCValue(ref: core.claimAndTrackHandle(ref), contextRef: core.contextRef)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCValue) -> JSCValue {
    core.transferToDefaultFrame(value.ref)
    return JSCValue(ref: value.ref, contextRef: core.contextRef)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing JSCValue) -> JSCValue {
    JSCValue(ref: value.ref, contextRef: core.contextRef)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> JSCValue {
    guard let ref = JSCEngine.makeStringValueHandle(value, core.contextRef) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeString(from key: borrowing JSCPropertyStringKey) -> JSCValue {
    guard
      let ref = JSCEngine.makeStringValueHandle(
        fromPropertyStringKey: key.borrowString(in: core.contextRef),
        in: core.contextRef
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeNumber(_ value: Double) -> JSCValue {
    guard let ref = JSCEngine.makeNumberValueHandle(value, core.contextRef) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeBoolean(_ value: Bool) -> JSCValue {
    guard let ref = JSCEngine.makeBooleanValueHandle(value, core.contextRef) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeNull() -> JSCValue {
    guard let ref = JSCEngine.makeNullValueHandle(core.contextRef) else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeUndefined() -> JSCValue {
    guard let ref = JSCEngine.makeUndefinedValueHandle(core.contextRef) else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeSymbol(_ value: String) -> JSCValue {
    guard let ref = JSCEngine.makeSymbolValueHandle(value, core.contextRef) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeObject() -> JSResult<JSCValue> {
    guard let result = JSCEngine.makeObjectResultHandle(core.contextRef) else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  public func makeArray() -> JSResult<JSCValue> {
    guard let result = JSCEngine.makeArrayResultHandle(core.contextRef) else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSCInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    try body(self)
  }

  // MARK: - Callback exit

  public func `return`(_ value: borrowing JSCValue) -> JSCCallbackReturn {
    JSCCallbackReturn(temporary: value.ref)
  }

  public func `throw`(_ value: borrowing JSCValue) -> JSCCallbackReturn {
    JSCCallbackReturn(exception: value.ref)
  }

  public func returnUndefined() -> JSCCallbackReturn {
    JSCCallbackReturn(temporary: makeUndefined().ref)
  }

  public func throwUndefined() -> JSCCallbackReturn {
    JSCCallbackReturn(exception: makeUndefined().ref)
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let ref = JSCEngine.globalObjectValueHandle(core.contextRef) else {
      preconditionFailure("JSCInstantContext.globalObjectValue could not get global object")
    }
    return JSCValue(ref: ref, contextRef: core.contextRef)
  }

  public func getGlobalProperty(forKey key: StaticString) -> JSCValue {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else {
      preconditionFailure("JSCInstantContext.getGlobalProperty could not get global object")
    }
    guard
      let result = JSCEngine.getStaticStringPropertyHandle(
        key,
        on: global,
        in: core.contextRef
      )
    else {
      preconditionFailure("JSCInstantContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let ref):
      return adoptCreatedHandle(ref)
    case .exception(let ref):
      guard let undefined = JSCEngine.makeUndefinedValueHandle(core.contextRef) else {
        preconditionFailure("JSCInstantContext could not create an undefined value")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing JSCValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else { return }
    _ = JSCEngine.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.ref,
      in: core.contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else { return }
    _ = JSCEngine.deleteStaticStringPropertyHandle(key, on: global, in: core.contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else {
      return false
    }
    return JSCEngine.hasStaticStringPropertyHandle(key, on: global, in: core.contextRef)
      ?? false
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCValue {
    guard
      let ref = JSCEngine.makeFunctionValueHandle(
        named: name,
        callback: callback,
        in: core.contextRef
      )
    else {
      preconditionFailure("makeFunctionValueHandle could not create function")
    }
    core.trackOnDefaultFrame(ref)
    return JSCValue(ref: ref, contextRef: core.contextRef)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing JSCValue
  ) -> JSCPersistentHandle {
    mintPersistentHandle(value.ref, of: core.contextRef)
  }

  @available(*, noasync)
  public func resolve(_ handle: JSCPersistentHandle) -> JSCValue? {
    guard
      let bindings = javaScriptCorePersistentBindings(for: core.contextRef),
      let ref = bindings.borrowLive(handle.identity)
    else {
      return nil
    }
    core.frame.track(ref)
    return JSCValue(ref: ref, contextRef: core.contextRef)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> JSCPropertyStringKey {
    guard let stringRef = JSCEngine.makePropertyStringKeyHandle(value, in: core.contextRef)
    else {
      preconditionFailure("makePropertyStringKeyHandle could not create key")
    }
    return JSCPropertyStringKey(
      stringRef: stringRef,
      contextRef: core.contextRef,
      context: JSCScopeStacks.context(for: core.contextRef)
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let scriptRef = JSCEngine.makePreparedScriptHandle(source, in: core.contextRef) else {
      preconditionFailure("makePreparedScriptHandle could not create script")
    }
    return JSCPreparedScript(
      scriptRef: scriptRef,
      contextRef: core.contextRef,
      context: JSCScopeStacks.context(for: core.contextRef)
    )
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing JSCPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValue> {
    guard
      let result = JSCEngine.evaluatePreparedScriptResultHandle(
        script.borrowScript(in: core.contextRef),
        core.contextRef,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSCInstantContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    JSCEngine.contextDataStorageBox(in: core.contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    JSCEngine.contextDataStorageBox(in: core.contextRef)?.data(for: key) ?? K.defaultValue
  }
}

/// The manual JavaScriptCore scope (`JSContext`-derived construction).
public struct JSCScope: SwiftJavaScript.JSScope, ~Copyable, ~Sendable {
  public typealias Context = JSCContext
  public typealias Value = JSCValue
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias InstantContext = JSCInstantContext
  public typealias PreparedScript = JSCPreparedScript
  public typealias PersistentHandle = JSCPersistentHandle

  private var core: JSCScopeCore
  private var isOpen = false

  package var contextRef: JSGlobalContextRef { core.contextRef }

  package init(contextRef: JSGlobalContextRef) {
    self.core = JSCScopeCore(contextRef: contextRef, rootsArenaValues: false)
  }

  /// Push the context scope stack and begin arena tracking. Idempotent.
  @available(*, noasync)
  package mutating func open() {
    guard !isOpen else { return }
    JSCScopeStacks.push(core)
    isOpen = true
  }

  deinit {
    core.drain()
    if isOpen {
      JSCScopeStacks.pop(for: core.contextRef)
    }
  }

  // MARK: - Ledger primitives

  package func adoptCreatedHandle(_ ref: JSValueRef) -> JSCValue {
    JSCValue(ref: core.trackCreatedHandle(ref), contextRef: core.contextRef)
  }

  package func anchorBorrowedHandle(_ ref: JSValueRef) -> JSCValue {
    JSCValue(ref: core.claimAndTrackHandle(ref), contextRef: core.contextRef)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCValue) -> JSCValue {
    core.transferToDefaultFrame(value.ref)
    return JSCValue(ref: value.ref, contextRef: core.contextRef)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing JSCValue) -> JSCValue {
    JSCValue(ref: value.ref, contextRef: core.contextRef)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> JSCValue {
    guard let ref = JSCEngine.makeStringValueHandle(value, core.contextRef) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeString(from key: borrowing JSCPropertyStringKey) -> JSCValue {
    guard
      let ref = JSCEngine.makeStringValueHandle(
        fromPropertyStringKey: key.borrowString(in: core.contextRef),
        in: core.contextRef
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeNumber(_ value: Double) -> JSCValue {
    guard let ref = JSCEngine.makeNumberValueHandle(value, core.contextRef) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeBoolean(_ value: Bool) -> JSCValue {
    guard let ref = JSCEngine.makeBooleanValueHandle(value, core.contextRef) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeNull() -> JSCValue {
    guard let ref = JSCEngine.makeNullValueHandle(core.contextRef) else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeUndefined() -> JSCValue {
    guard let ref = JSCEngine.makeUndefinedValueHandle(core.contextRef) else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeSymbol(_ value: String) -> JSCValue {
    guard let ref = JSCEngine.makeSymbolValueHandle(value, core.contextRef) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeObject() -> JSResult<JSCValue> {
    guard let result = JSCEngine.makeObjectResultHandle(core.contextRef) else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  public func makeArray() -> JSResult<JSCValue> {
    guard let result = JSCEngine.makeArrayResultHandle(core.contextRef) else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSCInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let window = JSCInstantContext(contextRef: core.contextRef)
    return try body(window)
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let ref = JSCEngine.globalObjectValueHandle(core.contextRef) else {
      preconditionFailure("JSCScope.globalObjectValue could not get global object")
    }
    return JSCValue(ref: ref, contextRef: core.contextRef)
  }

  public func getGlobalProperty(forKey key: StaticString) -> JSCValue {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else {
      preconditionFailure("JSCScope.getGlobalProperty could not get global object")
    }
    guard
      let result = JSCEngine.getStaticStringPropertyHandle(
        key,
        on: global,
        in: core.contextRef
      )
    else {
      preconditionFailure("JSCScope.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let ref):
      return adoptCreatedHandle(ref)
    case .exception(let ref):
      guard let undefined = JSCEngine.makeUndefinedValueHandle(core.contextRef) else {
        preconditionFailure("JSCScope could not create an undefined value")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing JSCValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else { return }
    _ = JSCEngine.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.ref,
      in: core.contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else { return }
    _ = JSCEngine.deleteStaticStringPropertyHandle(key, on: global, in: core.contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = JSCEngine.globalObjectValueHandle(core.contextRef) else {
      return false
    }
    return JSCEngine.hasStaticStringPropertyHandle(key, on: global, in: core.contextRef)
      ?? false
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCValue {
    guard
      let ref = JSCEngine.makeFunctionValueHandle(
        named: name,
        callback: callback,
        in: core.contextRef
      )
    else {
      preconditionFailure("makeFunctionValueHandle could not create function")
    }
    core.trackOnDefaultFrame(ref)
    return JSCValue(ref: ref, contextRef: core.contextRef)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing JSCValue
  ) -> JSCPersistentHandle {
    mintPersistentHandle(value.ref, of: core.contextRef)
  }

  @available(*, noasync)
  public func resolve(_ handle: JSCPersistentHandle) -> JSCValue? {
    guard
      let bindings = javaScriptCorePersistentBindings(for: core.contextRef),
      let ref = bindings.borrowLive(handle.identity)
    else {
      return nil
    }
    core.frame.track(ref)
    return JSCValue(ref: ref, contextRef: core.contextRef)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> JSCPropertyStringKey {
    guard let stringRef = JSCEngine.makePropertyStringKeyHandle(value, in: core.contextRef)
    else {
      preconditionFailure("makePropertyStringKeyHandle could not create key")
    }
    return JSCPropertyStringKey(
      stringRef: stringRef,
      contextRef: core.contextRef,
      context: JSCScopeStacks.context(for: core.contextRef)
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let scriptRef = JSCEngine.makePreparedScriptHandle(source, in: core.contextRef) else {
      preconditionFailure("makePreparedScriptHandle could not create script")
    }
    return JSCPreparedScript(
      scriptRef: scriptRef,
      contextRef: core.contextRef,
      context: JSCScopeStacks.context(for: core.contextRef)
    )
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing JSCPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValue> {
    guard
      let result = JSCEngine.evaluatePreparedScriptResultHandle(
        script.borrowScript(in: core.contextRef),
        core.contextRef,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSCScope.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    JSCEngine.contextDataStorageBox(in: core.contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    JSCEngine.contextDataStorageBox(in: core.contextRef)?.data(for: key) ?? K.defaultValue
  }
}

// MARK: - Persistent binding minting

@available(*, noasync)
private func mintPersistentHandle(
  _ ref: JSValueRef,
  of contextRef: JSGlobalContextRef
) -> JSCPersistentHandle {
  guard let bindings = javaScriptCorePersistentBindings(for: contextRef) else {
    preconditionFailure(
      "JSPersistentHandle minting requires a hosted JSContext (no registry installed)"
    )
  }
  guard let context = JSCScopeStacks.context(for: contextRef) else {
    preconditionFailure("JSPersistentHandle minting requires a live JSContext actor")
  }
  return JSCPersistentHandle(
    identity: bindings.mint(ref),
    registry: bindings,
    context: context
  )
}
