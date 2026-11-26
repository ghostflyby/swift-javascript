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
// top through the `QJSEngine` statics.

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct QJSInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
  public typealias CallbackReturn = QJSCallbackReturn
  public typealias CallbackArguments = QJSCallbackArguments
  public typealias Arguments = QJSArguments
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: QJSScopeCore

  package var contextRef: OpaquePointer { core.contextRef }

  package init(contextRef: OpaquePointer) {
    self.core = QJSScopeCore(contextRef: contextRef)
    QJSScopeStacks.push(core)
  }

  deinit {
    core.drain()
    QJSScopeStacks.pop(for: core.contextRef)
  }

  // MARK: - Ledger primitives

  package func adoptCreated(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.trackCreated(value), contextRef: core.contextRef)
  }

  package func adoptCallback(_ value: CQuickJSValue) -> QJSCallbackValue {
    QJSCallbackValue(value: core.trackCreated(value), contextRef: core.contextRef)
  }

  package func anchorBorrowed(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.claimAndTrack(value), contextRef: core.contextRef)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing QJSCallbackValue) -> QJSValue {
    core.transferToDefaultFrame(value.value)
    return QJSValue(value: value.value, contextRef: core.contextRef)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing QJSCallbackValue) -> QJSValue {
    QJSValue(value: value.value, contextRef: core.contextRef)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> QJSCallbackValue {
    guard let created = QJSEngine.makeString(value, in: core.contextRef) else {
      preconditionFailure("makeString failed")
    }
    return adoptCallback(created)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSCallbackValue {
    guard
      let created = QJSEngine.makeStringValue(
        fromAtom: key.borrowAtom(in: core.contextRef),
        in: core.contextRef
      )
    else {
      preconditionFailure("makeStringValue failed")
    }
    return adoptCallback(created)
  }

  public func makeNumber(_ value: Double) -> QJSCallbackValue {
    guard let created = QJSEngine.makeNumber(value, in: core.contextRef) else {
      preconditionFailure("makeNumber failed")
    }
    return adoptCallback(created)
  }

  public func makeBoolean(_ value: Bool) -> QJSCallbackValue {
    guard let created = QJSEngine.makeBoolean(value, in: core.contextRef) else {
      preconditionFailure("makeBoolean failed")
    }
    return adoptCallback(created)
  }

  public func makeNull() -> QJSCallbackValue {
    guard let created = QJSEngine.makeNull(in: core.contextRef) else {
      preconditionFailure("makeNull failed")
    }
    return adoptCallback(created)
  }

  public func makeUndefined() -> QJSCallbackValue {
    guard let created = QJSEngine.makeUndefined(in: core.contextRef) else {
      preconditionFailure("makeUndefined failed")
    }
    return adoptCallback(created)
  }

  public func makeSymbol(_ value: String) -> QJSCallbackValue {
    guard let created = QJSEngine.makeSymbol(value, in: core.contextRef) else {
      preconditionFailure("makeSymbol failed")
    }
    return adoptCallback(created)
  }

  public func makeObject() -> JSResult<QJSCallbackValue> {
    guard let result = QJSEngine.makeObjectResult(in: core.contextRef) else {
      preconditionFailure("makeObjectResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCallback(created))
    case .exception(let thrown):
      return .exception(adoptCallback(thrown))
    }
  }

  public func makeArray() -> JSResult<QJSCallbackValue> {
    guard let result = QJSEngine.makeArrayResult(in: core.contextRef) else {
      preconditionFailure("makeArrayResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCallback(created))
    case .exception(let thrown):
      return .exception(adoptCallback(thrown))
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
    QJSCallbackReturn(temporary: value.value)
  }

  public func `return`(_ value: borrowing QJSValue) -> QJSCallbackReturn {
    QJSCallbackReturn(temporary: value.value)
  }

  public func `throw`(_ value: borrowing QJSCallbackValue) -> QJSCallbackReturn {
    QJSCallbackReturn(exception: value.value)
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

  public func globalObjectValue() -> QJSValue {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else {
      preconditionFailure("QJSInstantContext.globalObjectValue could not get global object")
    }
    return QJSValue(value: global, contextRef: core.contextRef)
  }

  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else {
      preconditionFailure("QJSInstantContext.getGlobalProperty could not get global object")
    }
    guard
      let result = QJSEngine.getStaticStringProperty(
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
      quickJSUpdateStackTop(core.contextRef)
      JS_FreeValue(core.contextRef, thrown)
      guard let undefined = QJSEngine.makeUndefined(in: core.contextRef) else {
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
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else { return }
    _ = QJSEngine.setStaticStringProperty(
      key,
      on: global,
      to: value.value,
      in: core.contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else { return }
    _ = QJSEngine.deleteStaticStringProperty(key, on: global, in: core.contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else {
      return false
    }
    return QJSEngine.hasStaticStringProperty(key, on: global, in: core.contextRef) ?? false
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let created = QJSEngine.makeFunction(
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
    _ value: borrowing QJSCallbackValue
  ) -> QJSPersistentHandle {
    mintPersistentHandle(value.value, of: value.contextRef, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(_ value: borrowing QJSValue) -> QJSPersistentHandle {
    mintPersistentHandle(value.value, of: value.contextRef, on: core)
  }

  @available(*, noasync)
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
    guard let atom = QJSEngine.makePropertyStringAtom(value, in: core.contextRef) else {
      preconditionFailure("makePropertyStringAtom could not create a key")
    }
    return QJSPropertyStringKey(
      atom: atom,
      contextRef: core.contextRef,
      vmThread: QJSScopeStacks.vmThread(for: core.contextRef)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    QJSPreparedScript(
      source: source,
      contextRef: core.contextRef,
      vmThread: QJSScopeStacks.vmThread(for: core.contextRef)
    )
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let result = QJSEngine.evaluateScript(
      script.borrowSource(in: core.contextRef),
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
    QJSEngine.contextDataStorageBox(in: core.contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    QJSEngine.contextDataStorageBox(in: core.contextRef)?.data(for: key) ?? K.defaultValue
  }
}

/// The manual QuickJS scope (`JSContext`-derived construction).
public struct QJSScope: SwiftJavaScript.JSScope, ~Copyable, ~Sendable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
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

  package func adoptCreated(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.trackCreated(value), contextRef: core.contextRef)
  }

  package func adoptCallback(_ value: CQuickJSValue) -> QJSCallbackValue {
    QJSCallbackValue(value: core.trackCreated(value), contextRef: core.contextRef)
  }

  package func anchorBorrowed(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: core.claimAndTrack(value), contextRef: core.contextRef)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing QJSCallbackValue) -> QJSValue {
    core.transferToDefaultFrame(value.value)
    return QJSValue(value: value.value, contextRef: core.contextRef)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing QJSCallbackValue) -> QJSValue {
    QJSValue(value: value.value, contextRef: core.contextRef)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> QJSCallbackValue {
    guard let created = QJSEngine.makeString(value, in: core.contextRef) else {
      preconditionFailure("makeString failed")
    }
    return adoptCallback(created)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSCallbackValue {
    guard
      let created = QJSEngine.makeStringValue(
        fromAtom: key.borrowAtom(in: core.contextRef),
        in: core.contextRef
      )
    else {
      preconditionFailure("makeStringValue failed")
    }
    return adoptCallback(created)
  }

  public func makeNumber(_ value: Double) -> QJSCallbackValue {
    guard let created = QJSEngine.makeNumber(value, in: core.contextRef) else {
      preconditionFailure("makeNumber failed")
    }
    return adoptCallback(created)
  }

  public func makeBoolean(_ value: Bool) -> QJSCallbackValue {
    guard let created = QJSEngine.makeBoolean(value, in: core.contextRef) else {
      preconditionFailure("makeBoolean failed")
    }
    return adoptCallback(created)
  }

  public func makeNull() -> QJSCallbackValue {
    guard let created = QJSEngine.makeNull(in: core.contextRef) else {
      preconditionFailure("makeNull failed")
    }
    return adoptCallback(created)
  }

  public func makeUndefined() -> QJSCallbackValue {
    guard let created = QJSEngine.makeUndefined(in: core.contextRef) else {
      preconditionFailure("makeUndefined failed")
    }
    return adoptCallback(created)
  }

  public func makeSymbol(_ value: String) -> QJSCallbackValue {
    guard let created = QJSEngine.makeSymbol(value, in: core.contextRef) else {
      preconditionFailure("makeSymbol failed")
    }
    return adoptCallback(created)
  }

  public func makeObject() -> JSResult<QJSCallbackValue> {
    guard let result = QJSEngine.makeObjectResult(in: core.contextRef) else {
      preconditionFailure("makeObjectResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCallback(created))
    case .exception(let thrown):
      return .exception(adoptCallback(thrown))
    }
  }

  public func makeArray() -> JSResult<QJSCallbackValue> {
    guard let result = QJSEngine.makeArrayResult(in: core.contextRef) else {
      preconditionFailure("makeArrayResult failed")
    }
    switch consume result {
    case .value(let created):
      return .value(adoptCallback(created))
    case .exception(let thrown):
      return .exception(adoptCallback(thrown))
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

  public func globalObjectValue() -> QJSValue {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else {
      preconditionFailure("QJSScope.globalObjectValue could not get global object")
    }
    return QJSValue(value: global, contextRef: core.contextRef)
  }

  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else {
      preconditionFailure("QJSScope.getGlobalProperty could not get global object")
    }
    guard
      let result = QJSEngine.getStaticStringProperty(
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
      quickJSUpdateStackTop(core.contextRef)
      JS_FreeValue(core.contextRef, thrown)
      guard let undefined = QJSEngine.makeUndefined(in: core.contextRef) else {
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
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else { return }
    _ = QJSEngine.setStaticStringProperty(
      key,
      on: global,
      to: value.value,
      in: core.contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else { return }
    _ = QJSEngine.deleteStaticStringProperty(key, on: global, in: core.contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = QJSEngine.globalObjectValue(core.contextRef) else {
      return false
    }
    return QJSEngine.hasStaticStringProperty(key, on: global, in: core.contextRef) ?? false
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let created = QJSEngine.makeFunction(
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
    _ value: borrowing QJSCallbackValue
  ) -> QJSPersistentHandle {
    mintPersistentHandle(value.value, of: value.contextRef, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(_ value: borrowing QJSValue) -> QJSPersistentHandle {
    mintPersistentHandle(value.value, of: value.contextRef, on: core)
  }

  @available(*, noasync)
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
    guard let atom = QJSEngine.makePropertyStringAtom(value, in: core.contextRef) else {
      preconditionFailure("makePropertyStringAtom could not create a key")
    }
    return QJSPropertyStringKey(
      atom: atom,
      contextRef: core.contextRef,
      vmThread: QJSScopeStacks.vmThread(for: core.contextRef)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    QJSPreparedScript(
      source: source,
      contextRef: core.contextRef,
      vmThread: QJSScopeStacks.vmThread(for: core.contextRef)
    )
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let result = QJSEngine.evaluateScript(
      script.borrowSource(in: core.contextRef),
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
    QJSEngine.contextDataStorageBox(in: core.contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    QJSEngine.contextDataStorageBox(in: core.contextRef)?.data(for: key) ?? K.defaultValue
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
  of contextRef: OpaquePointer,
  on core: borrowing QJSScopeCore
) -> QJSPersistentHandle {
  precondition(
    contextRef == core.contextRef,
    "JSPersistentHandle can only be minted for values of its own context"
  )
  guard let bindings = quickJSPersistentBindings(for: core.contextRef) else {
    preconditionFailure(
      "JSPersistentHandle minting requires a hosted JSContext (no bindings installed)"
    )
  }
  return QJSPersistentHandle(identity: bindings.mint(value), registry: bindings)
}
