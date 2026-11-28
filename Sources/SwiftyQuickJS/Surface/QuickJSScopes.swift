import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

// MARK: - QuickJS scopes
//
// Both scopes own one concrete `QJSScopeCore`: a frame of owned
// `CQuickJSValue` references (+1 each) that `JS_FreeValue` settles on drain.
// The operations that create and adopt values (factories, global reads,
// script results, function/key/script construction, context data) are
// implemented here, on this scope's frame. What stays in core is the
// value-level composition that never adopts (the installed-function wrapper,
// the callback-value global write). Engine calls refresh the runtime's stack
// top through the `QuickJS` statics.

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct QJSInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias CallbackReturn = QJSCallbackReturn
  public typealias CallbackArguments = QJSCallbackArguments
  public typealias Arguments = QJSArguments
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: QJSScopeCore

  package var contextRef: OpaquePointer { core.contextRef }

  @_lifetime(borrow self)
  public func value(from argument: borrowing QJSCallArgument) -> QJSValue {
    QJSValue(value: argument.value, contextRef: contextRef)
  }

  package init(contextRef: OpaquePointer) {
    self.core = QJSScopeCore(contextRef: contextRef)
    QJSScopeStacks.push(core)
  }

  deinit {
    core.drain()
    QJSScopeStacks.pop(for: core.contextRef)
  }

  // MARK: - Ledger primitives

  @_lifetime(borrow self)
  package func adoptCreated(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.trackCreated(value), contextRef: core.contextRef)
  }

  @_lifetime(borrow self)
  package func anchorBorrowed(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.claimAndTrack(value), contextRef: core.contextRef)
  }

  // MARK: - Scope operations

  @_lifetime(borrow self)
  public func persist(_ value: borrowing QJSValue) -> QJSValue {
    core.transferToDefaultFrame(value.value)
    return QJSValue(value: value.value, contextRef: core.contextRef)
  }

  @available(*, noasync)
  @_lifetime(borrow self)
  public func localValue(_ value: borrowing QJSValue) -> QJSValue {
    QJSValue(value: value.value, contextRef: core.contextRef)
  }

  // MARK: - Value factories

  @_lifetime(borrow self)
  public func makeString(_ value: String) -> QJSValue {
    guard let created = quickJSMakeString(value, in: core.contextRef) else {
      preconditionFailure("makeString failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSValue {
    guard
      let created = quickJSMakeStringValue(
        fromAtom: key.borrowAtom(in: core.contextRef),
        in: core.contextRef
      )
    else {
      preconditionFailure("makeStringValue failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeNumber(_ value: Double) -> QJSValue {
    guard let created = quickJSMakeNumber(value, in: core.contextRef) else {
      preconditionFailure("makeNumber failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeBoolean(_ value: Bool) -> QJSValue {
    guard let created = quickJSMakeBoolean(value, in: core.contextRef) else {
      preconditionFailure("makeBoolean failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeNull() -> QJSValue {
    guard let created = quickJSMakeNull(in: core.contextRef) else {
      preconditionFailure("makeNull failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeUndefined() -> QJSValue {
    guard let created = quickJSMakeUndefined(in: core.contextRef) else {
      preconditionFailure("makeUndefined failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeSymbol(_ value: String) -> QJSValue {
    guard let created = quickJSMakeSymbol(value, in: core.contextRef) else {
      preconditionFailure("makeSymbol failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeObject() -> JSResult<QJSValue> {
    guard let result = quickJSMakeObjectResult(in: core.contextRef) else {
      preconditionFailure("makeObjectResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCreated(created))
    case .exception(let thrown):
      return .exception(adoptCreated(thrown))
    }
  }

  @_lifetime(borrow self)
  public func makeArray() -> JSResult<QJSValue> {
    guard let result = quickJSMakeArrayResult(in: core.contextRef) else {
      preconditionFailure("makeArrayResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCreated(created))
    case .exception(let thrown):
      return .exception(adoptCreated(thrown))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing QJSInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    try body(self)
  }

  // MARK: - Callback exit

  public func `return`(_ value: borrowing QJSValue) -> QJSCallbackReturn {
    QJSCallbackReturn(temporary: value.value)
  }

  public func `throw`(_ value: borrowing QJSValue) -> QJSCallbackReturn {
    QJSCallbackReturn(exception: value.value)
  }

  public func returnUndefined() -> QJSCallbackReturn {
    QJSCallbackReturn(temporary: makeUndefined().value)
  }

  public func throwUndefined() -> QJSCallbackReturn {
    QJSCallbackReturn(exception: makeUndefined().value)
  }

  // MARK: - Global object

  @_lifetime(borrow self)
  public func globalObjectValue() -> QJSValue {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else {
      preconditionFailure("QJSInstantContext.globalObjectValue could not get global object")
    }
    return QJSValue(value: global, contextRef: core.contextRef)
  }

  @_lifetime(borrow self)
  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else {
      preconditionFailure("QJSInstantContext.getGlobalProperty could not get global object")
    }
    guard
      let result = quickJSGetStaticStringProperty(
        key,
        on: global,
        in: core.contextRef
      )
    else {
      preconditionFailure("QJSInstantContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let created):
      return adoptCreated(created)
    case .exception(let thrown):
      JS_FreeValue(core.contextRef, thrown)
      guard let undefined = quickJSMakeUndefined(in: core.contextRef) else {
        preconditionFailure("QJSInstantContext could not create an undefined value")
      }
      return adoptCreated(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing QJSValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else { return }
    _ = quickJSSetStaticStringProperty(
      key,
      on: global,
      to: value.value,
      in: core.contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else { return }
    _ = quickJSDeleteStaticStringProperty(key, on: global, in: core.contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else {
      return false
    }
    return quickJSHasStaticStringProperty(key, on: global, in: core.contextRef) ?? false
  }

  @_lifetime(borrow self)
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let created = quickJSMakeFunction(
        named: name,
        callback: callback,
        in: core.contextRef
      )
    else {
      preconditionFailure("makeFunction could not create a function")
    }
    core.trackOnDefaultFrame(created)
    return QJSValue(value: created, contextRef: core.contextRef)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing QJSValue
  ) -> QJSPersistentHandle {
    mintPersistentHandle(value.value, of: value.contextRef, on: core)
  }

  @available(*, noasync)
  @_lifetime(borrow self)
  public func resolve(_ handle: QJSPersistentHandle) -> QJSValue? {
    guard
      let bindings = quickJSPersistentBindings(for: core.contextRef),
      let borrowed = bindings.borrowLive(handle.identity)
    else {
      return nil
    }
    return anchorBorrowed(borrowed)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> QJSPropertyStringKey {
    guard let atom = quickJSMakePropertyStringAtom(value, in: core.contextRef) else {
      preconditionFailure("makePropertyStringAtom could not create a key")
    }
    return QJSPropertyStringKey(
      atom: atom,
      contextRef: core.contextRef,
      context: QJSScopeStacks.context(for: core.contextRef)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    return QJSPreparedScript(source: source)
  }

  // MARK: - Scripts

  @_lifetime(borrow self)
  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let result = quickJSEvaluateScript(
      script.source,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber,
      in: core.contextRef
    )
    switch consume result {
    case .value(let created):
      return .value(adoptCreated(created))
    case .exception(let thrown):
      return .exception(adoptCreated(thrown))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    quickJSContextDataStorageBox(in: core.contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    quickJSContextDataStorageBox(in: core.contextRef)?.data(for: key) ?? K.defaultValue
  }
}

/// The manual QuickJS scope (`JSContext`-derived construction).
public struct QJSScope: SwiftJavaScript.JSScope, ~Copyable, ~Sendable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias InstantContext = QJSInstantContext
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: QJSScopeCore
  private var isOpen = false

  package var contextRef: OpaquePointer { core.contextRef }

  package init(contextRef: OpaquePointer) {
    self.core = QJSScopeCore(contextRef: contextRef)
  }

  /// Push the context scope stack and begin arena tracking. Idempotent.
  @available(*, noasync)
  package mutating func open() {
    guard !isOpen else { return }
    QJSScopeStacks.push(core)
    isOpen = true
  }

  deinit {
    core.drain()
    if isOpen { QJSScopeStacks.pop(for: core.contextRef) }
  }

  // MARK: - Ledger primitives

  @_lifetime(borrow self)
  package func adoptCreated(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.trackCreated(value), contextRef: core.contextRef)
  }

  @_lifetime(borrow self)
  package func anchorBorrowed(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.claimAndTrack(value), contextRef: core.contextRef)
  }

  // MARK: - Scope operations

  @_lifetime(borrow self)
  public func persist(_ value: borrowing QJSValue) -> QJSValue {
    core.transferToDefaultFrame(value.value)
    return QJSValue(value: value.value, contextRef: core.contextRef)
  }

  @available(*, noasync)
  @_lifetime(borrow self)
  public func localValue(_ value: borrowing QJSValue) -> QJSValue {
    QJSValue(value: value.value, contextRef: core.contextRef)
  }

  // MARK: - Value factories

  @_lifetime(borrow self)
  public func makeString(_ value: String) -> QJSValue {
    guard let created = quickJSMakeString(value, in: core.contextRef) else {
      preconditionFailure("makeString failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSValue {
    guard
      let created = quickJSMakeStringValue(
        fromAtom: key.borrowAtom(in: core.contextRef),
        in: core.contextRef
      )
    else {
      preconditionFailure("makeStringValue failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeNumber(_ value: Double) -> QJSValue {
    guard let created = quickJSMakeNumber(value, in: core.contextRef) else {
      preconditionFailure("makeNumber failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeBoolean(_ value: Bool) -> QJSValue {
    guard let created = quickJSMakeBoolean(value, in: core.contextRef) else {
      preconditionFailure("makeBoolean failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeNull() -> QJSValue {
    guard let created = quickJSMakeNull(in: core.contextRef) else {
      preconditionFailure("makeNull failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeUndefined() -> QJSValue {
    guard let created = quickJSMakeUndefined(in: core.contextRef) else {
      preconditionFailure("makeUndefined failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeSymbol(_ value: String) -> QJSValue {
    guard let created = quickJSMakeSymbol(value, in: core.contextRef) else {
      preconditionFailure("makeSymbol failed")
    }
    return adoptCreated(created)
  }

  @_lifetime(borrow self)
  public func makeObject() -> JSResult<QJSValue> {
    guard let result = quickJSMakeObjectResult(in: core.contextRef) else {
      preconditionFailure("makeObjectResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCreated(created))
    case .exception(let thrown):
      return .exception(adoptCreated(thrown))
    }
  }

  @_lifetime(borrow self)
  public func makeArray() -> JSResult<QJSValue> {
    guard let result = quickJSMakeArrayResult(in: core.contextRef) else {
      preconditionFailure("makeArrayResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCreated(created))
    case .exception(let thrown):
      return .exception(adoptCreated(thrown))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing QJSInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let window = QJSInstantContext(contextRef: core.contextRef)
    return try body(window)
  }

  // MARK: - Global object

  @_lifetime(borrow self)
  public func globalObjectValue() -> QJSValue {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else {
      preconditionFailure("QJSScope.globalObjectValue could not get global object")
    }
    return QJSValue(value: global, contextRef: core.contextRef)
  }

  @_lifetime(borrow self)
  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else {
      preconditionFailure("QJSScope.getGlobalProperty could not get global object")
    }
    guard
      let result = quickJSGetStaticStringProperty(
        key,
        on: global,
        in: core.contextRef
      )
    else {
      preconditionFailure("QJSScope.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let created):
      return adoptCreated(created)
    case .exception(let thrown):
      JS_FreeValue(core.contextRef, thrown)
      guard let undefined = quickJSMakeUndefined(in: core.contextRef) else {
        preconditionFailure("QJSScope could not create an undefined value")
      }
      return adoptCreated(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing QJSValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else { return }
    _ = quickJSSetStaticStringProperty(
      key,
      on: global,
      to: value.value,
      in: core.contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else { return }
    _ = quickJSDeleteStaticStringProperty(key, on: global, in: core.contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = quickJSGlobalObjectValue(core.contextRef) else {
      return false
    }
    return quickJSHasStaticStringProperty(key, on: global, in: core.contextRef) ?? false
  }

  @_lifetime(borrow self)
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let created = quickJSMakeFunction(
        named: name,
        callback: callback,
        in: core.contextRef
      )
    else {
      preconditionFailure("makeFunction could not create a function")
    }
    core.trackOnDefaultFrame(created)
    return QJSValue(value: created, contextRef: core.contextRef)
  }

  // MARK: - Persistent bindings

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing QJSValue
  ) -> QJSPersistentHandle {
    mintPersistentHandle(value.value, of: value.contextRef, on: core)
  }

  @available(*, noasync)
  @_lifetime(borrow self)
  public func resolve(_ handle: QJSPersistentHandle) -> QJSValue? {
    guard
      let bindings = quickJSPersistentBindings(for: core.contextRef),
      let borrowed = bindings.borrowLive(handle.identity)
    else {
      return nil
    }
    return anchorBorrowed(borrowed)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> QJSPropertyStringKey {
    guard let atom = quickJSMakePropertyStringAtom(value, in: core.contextRef) else {
      preconditionFailure("makePropertyStringAtom could not create a key")
    }
    return QJSPropertyStringKey(
      atom: atom,
      contextRef: core.contextRef,
      context: QJSScopeStacks.context(for: core.contextRef)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    return QJSPreparedScript(source: source)
  }

  // MARK: - Scripts

  @_lifetime(borrow self)
  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let result = quickJSEvaluateScript(
      script.source,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber,
      in: core.contextRef
    )
    switch consume result {
    case .value(let created):
      return .value(adoptCreated(created))
    case .exception(let thrown):
      return .exception(adoptCreated(thrown))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    quickJSContextDataStorageBox(in: core.contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    quickJSContextDataStorageBox(in: core.contextRef)?.data(for: key) ?? K.defaultValue
  }
}

// MARK: - Persistent binding minting
//
// Both scopes mint the same way: through the context's binding table, which
// only a hosted `QJSContext` installs (a raw callback context has no data box).

/// Mint a persistent binding for `value`, addressed through `contextRef`.
@available(*, noasync)
private func mintPersistentHandle(
  _ value: CQuickJSValue,
  of contextRef: OpaquePointer?,
  on core: borrowing QJSScopeCore
) -> QJSPersistentHandle {
  precondition(
    contextRef == nil || contextRef == core.contextRef,
    "JSPersistentHandle can only be minted for context-free values or values of its own context"
  )
  guard let bindings = quickJSPersistentBindings(for: core.contextRef) else {
    preconditionFailure(
      "JSPersistentHandle minting requires a hosted JSContext (no bindings installed)"
    )
  }
  guard let context = QJSScopeStacks.context(for: core.contextRef) else {
    preconditionFailure("JSPersistentHandle minting requires a live JSContext actor")
  }
  return QJSPersistentHandle(
    identity: bindings.mint(value),
    registry: bindings,
    context: context
  )
}
