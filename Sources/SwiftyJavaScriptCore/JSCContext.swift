import JavaScriptCore
import SwiftJavaScript

/// The JavaScriptCore context actor.
///
/// Holds the engine handle, the VM it belongs to, and the shared
/// `JSContextStorage<JSCContextHandle>` that owns the default scope, the
/// persistent registry, and the context data box. The context-level factories,
/// global reads/writes, script evaluation, and data storage create or settle
/// engine references on the context default scope, so they live here rather
/// than in a core default; the actor also runs the storage teardown in its
/// isolated deinit, on the VM thread.
public actor JSCContext: SwiftJavaScript.JSContext {
  public typealias VirtualMachine = JSCVirtualMachine
  public typealias InstantContext = JSCInstantContext
  public typealias Scope = JSCScope
  public typealias Value = JSCValue
  public typealias CallbackValue = JSCCallbackValue
  public typealias CallbackReturn = JSCCallbackReturn
  public typealias CallbackArguments = JSCCallbackArguments
  public typealias PersistentHandle = JSCPersistentHandle
  public typealias Arguments = JSCArguments
  public typealias ArrayBuffer = JSCArrayBuffer
  public typealias TypedArray = JSCTypedArray
  public typealias Class = JSCClass
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias PreparedScript = JSCPreparedScript

  /// The engine context identity every operation of this actor is addressed
  /// through. Package-internal: it is a handle, so it must not appear in a
  /// public signature.
  package nonisolated let driverContextHandle: JSCContextHandle
  public nonisolated let virtualMachine: JSCVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// The same identity as the shared driver interface, for package-internal
  /// seams (the scope witness and the contract tests' driver dispatch). This
  /// lets those call sites avoid naming the handle type.
  package nonisolated var runtimeDriver: any JSContextRuntimeDriver { driverContextHandle }

  private let storage: JSContextStorage<JSCContextHandle>

  public init() {
    self.init(virtualMachine: JSCVirtualMachine())
  }

  /// Engine access only on the VM thread: `makeContextHandle` creates the
  /// context there, and this initializer's data-box install is posted there
  /// too. `init` is synchronous: a caller on another thread waits for it, a
  /// caller already on the VM thread (inside another context's window) runs
  /// inline.
  public init(virtualMachine: JSCVirtualMachine) {
    guard let driverContextHandle = virtualMachine.makeContextHandle() else {
      preconditionFailure("JSCContext could not create a context handle from its runtime")
    }
    self.init(virtualMachine: virtualMachine, driverContextHandle: driverContextHandle)
  }

  package init(
    virtualMachine: JSCVirtualMachine,
    driverContextHandle: JSCContextHandle
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.driverContextHandle = driverContextHandle
    let storage = JSContextStorage<JSCContextHandle>(
      driverContextHandle: driverContextHandle,
      scheduler: virtualMachine.persistentCleanupScheduler,
      vmThread: virtualMachine.vmThread
    )
    self.storage = storage
    // The context data box exists from the end of init: synchronous scope
    // witnesses reach the registry through it, and the box remembers this
    // actor as its unretained owner (used by raw callback contexts).
    storage.attachDataBox(bindingOwner: self)
  }

  /// Isolated deinit (SE-0371): runs on the actor's dedicated VM thread, so
  /// the engine-touching teardown never executes on a foreign thread. The
  /// storage owns the order: registry close → default-scope drain → box clear
  /// → context release → scope-stack pop.
  isolated deinit {
    storage.teardown()
  }

  // MARK: - Synchronous scopes

  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSCInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = JSCInstantContext(handle: driverContextHandle)
    return try body(instantContext)
  }

  public func makeScope() -> JSCScope {
    var scope = JSCScope(handle: driverContextHandle)
    scope.open()
    return scope
  }

  // MARK: - Ledger primitives
  //
  // Engine internals (package, never public): every context-level operation
  // below creates or settles an engine reference on the context default scope
  // through these two.

  package func adoptCreatedHandle(_ handle: consuming JSCOwnedValueHandle) -> JSCValue {
    JSCValue(
      handle: storage.defaultScope.trackCreatedHandle(handle),
      contextHandle: driverContextHandle
    )
  }

  package func anchorBorrowedHandle(_ handle: JSCValueHandle) -> JSCValue {
    JSCValue(
      handle: storage.defaultScope.claimAndTrackHandle(handle),
      contextHandle: driverContextHandle
    )
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> JSCValue {
    guard let handle = driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeString(from key: borrowing JSCPropertyStringKey) -> JSCValue {
    guard
      let handle = driverContextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: driverContextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNumber(_ value: Double) -> JSCValue {
    guard let handle = driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> JSCValue {
    guard let handle = driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNull() -> JSCValue {
    guard let handle = driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeUndefined() -> JSCValue {
    guard let handle = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeObject() -> JSCValue {
    guard let result = driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("JSCContext.makeObject failed")
    }
  }

  public func makeArray() -> JSCValue {
    guard let result = driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("JSCContext.makeArray failed")
    }
  }

  /// The creation reference is adopted by the context default scope, so the
  /// function outlives any single window.
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<JSCInstantContext>
  ) -> JSCValue {
    guard
      let handle = driverContextHandle.makeFunctionValueHandle(named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    return adoptCreatedHandle(handle)
  }

  // MARK: - Persistent bindings

  public func makePersistentHandle(_ value: borrowing JSCValue) -> JSCPersistentHandle {
    precondition(
      value.contextHandle == driverContextHandle,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    return JSCPersistentHandle(
      identity: storage.persistentRegistry.mintIdentity(value.borrowHandle()),
      registry: storage.persistentRegistry
    )
  }

  public func resolve(_ handle: JSCPersistentHandle) -> JSCValue? {
    guard let borrowed = storage.persistentRegistry.borrowLive(handle.identity) else {
      return nil
    }
    return JSCValue(
      handle: storage.defaultScope.claimAndTrackHandle(borrowed),
      contextHandle: driverContextHandle
    )
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> JSCPropertyStringKey {
    guard let handle = driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return JSCPropertyStringKey(
      handle: handle,
      contextHandle: driverContextHandle,
      vmThread: ScopeStackRegistry<JSCContextHandle>.vmThread(for: driverContextHandle)
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let handle = driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return JSCPreparedScript(
      handle: handle,
      contextHandle: driverContextHandle,
      vmThread: ScopeStackRegistry<JSCContextHandle>.vmThread(for: driverContextHandle)
    )
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let handle = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCContext.globalObjectValue could not get global object")
    }
    return JSCValue(handle: handle, contextHandle: driverContextHandle)
  }

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> JSCValue {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSCContext.getGlobalProperty could not get global object")
    }
    guard let result = driverContextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("JSCContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      driverContextHandle.releaseCreatedHandle(JSCOwnedValueHandle.adopting(handle))
      guard let undefined = driverContextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("JSCContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing JSCValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
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

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing JSCPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValue> {
    guard
      let result = driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSCContext.evaluateScript unexpectedly returned nil")
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
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }

  // MARK: - Identity

  /// Force a JavaScriptCore collection. Engine work: callers run on the VM
  /// thread (a callback window or the actor's isolation). Package-internal so
  /// the shared contract tests can force collection without a public handle
  /// API; `JSGarbageCollect` takes the context ref, not the context group.
  package nonisolated func collectGarbage() {
    JSGarbageCollect(driverContextHandle.ref)
  }

  public nonisolated static func == (lhs: JSCContext, rhs: JSCContext) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
