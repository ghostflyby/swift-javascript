import SwiftJavaScript

// MARK: - JavaScriptCore scopes
//
// Both scopes hold the shared `ScopeCore<JSCContextHandle, JSImplicitStackRoots>`:
// push/pop and arena settlement stay in core, and the value factories, global
// reads and script evaluation are the protocol defaults. What remains here is
// the engine's part: wrapping tracked handles in `JSCValue`/`JSCCallbackValue`
// and the few operations that build engine wrapper types.

/// The synchronous callback window handed to a `JSFunctionCallback`.
public struct JSCInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = JSCContext
  public typealias ContextHandle = JSCContextHandle
  public typealias Value = JSCValue
  public typealias CallbackValue = JSCCallbackValue
  public typealias CallbackReturn = JSCCallbackReturn
  public typealias CallbackArguments = JSCCallbackArguments
  public typealias Arguments = JSCArguments
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias PreparedScript = JSCPreparedScript
  public typealias PersistentHandle = JSCPersistentHandle

  private var core: ScopeCore<JSCContextHandle, JSImplicitStackRoots>

  public var driverContextHandle: JSCContextHandle { core.driverContextHandle }

  package init(handle: JSCContextHandle) {
    self.core = ScopeCore(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<JSCContextHandle>.pop(for: core.driverContextHandle)
  }

  // MARK: - Ledger primitives

  public func adoptCreatedHandle(_ handle: consuming JSCOwnedValueHandle) -> JSCValue {
    JSCValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func adoptCallbackHandle(
    _ handle: consuming JSCOwnedValueHandle
  ) -> JSCCallbackValue {
    JSCCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: JSCValueHandle) -> JSCValue {
    JSCValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCCallbackValue) -> JSCValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return JSCValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
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
  public typealias ContextHandle = JSCContextHandle
  public typealias Value = JSCValue
  public typealias CallbackValue = JSCCallbackValue
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias InstantContext = JSCInstantContext
  public typealias PreparedScript = JSCPreparedScript
  public typealias PersistentHandle = JSCPersistentHandle

  private var core: ScopeCore<JSCContextHandle, JSImplicitStackRoots>
  private var isOpen = false

  public var driverContextHandle: JSCContextHandle { core.driverContextHandle }

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

  public func adoptCreatedHandle(_ handle: consuming JSCOwnedValueHandle) -> JSCValue {
    JSCValue(handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func adoptCallbackHandle(
    _ handle: consuming JSCOwnedValueHandle
  ) -> JSCCallbackValue {
    JSCCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: JSCValueHandle) -> JSCValue {
    JSCValue(handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCCallbackValue) -> JSCValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return JSCValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCScope.globalObjectValue could not get global object")
    }
    return JSCValue(handle: handle, contextHandle: core.driverContextHandle)
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
