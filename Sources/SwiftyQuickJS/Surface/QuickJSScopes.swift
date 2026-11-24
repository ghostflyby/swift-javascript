import SwiftJavaScript

// MARK: - QuickJS scopes
//
// Both scopes hold the shared `ScopeCore<QJSContextHandle, JSImplicitStackRoots>`:
// push/pop and arena settlement stay in core, and the value factories, global
// reads and script evaluation are the protocol defaults. What remains here is
// the engine's part: wrapping tracked handles in `QJSValue`/`QJSCallbackValue`
// and the few operations that build engine wrapper types. QuickJS touches its
// stack top from the value handle's `ref` accessor (`JS_UpdateStackTop`), so
// the scope itself never needs a separate update call.

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct QJSInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = QJSContext
  public typealias ContextHandle = QJSContextHandle
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
  public typealias CallbackReturn = QJSCallbackReturn
  public typealias CallbackArguments = QJSCallbackArguments
  public typealias Arguments = QJSArguments
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: ScopeCore<QJSContextHandle, JSImplicitStackRoots>

  public var driverContextHandle: QJSContextHandle { core.driverContextHandle }

  package init(handle: QJSContextHandle) {
    self.core = ScopeCore(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<QJSContextHandle>.pop(for: core.driverContextHandle)
  }

  // MARK: - Ledger primitives

  public func adoptCreatedHandle(_ handle: consuming QJSOwnedValueHandle) -> QJSValue {
    QJSValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func adoptCallbackHandle(
    _ handle: consuming QJSOwnedValueHandle
  ) -> QJSCallbackValue {
    QJSCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: QJSValueHandle) -> QJSValue {
    QJSValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing QJSCallbackValue) -> QJSValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return QJSValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
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
  public typealias ContextHandle = QJSContextHandle
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias InstantContext = QJSInstantContext
  public typealias PreparedScript = QJSPreparedScript
  public typealias PersistentHandle = QJSPersistentHandle

  private var core: ScopeCore<QJSContextHandle, JSImplicitStackRoots>
  private var isOpen = false

  public var driverContextHandle: QJSContextHandle { core.driverContextHandle }

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

  public func adoptCreatedHandle(_ handle: consuming QJSOwnedValueHandle) -> QJSValue {
    QJSValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func adoptCallbackHandle(
    _ handle: consuming QJSOwnedValueHandle
  ) -> QJSCallbackValue {
    QJSCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: QJSValueHandle) -> QJSValue {
    QJSValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing QJSCallbackValue) -> QJSValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return QJSValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Global object

  public func globalObjectValue() -> QJSValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSScope.globalObjectValue could not get global object")
    }
    return QJSValue(handle: handle, contextHandle: core.driverContextHandle)
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
