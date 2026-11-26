import SwiftJavaScript

/// The QuickJS context actor.
///
/// Holds the engine handle, the VM it belongs to, and the shared
/// `JSContextStorage<QJSContextHandle>` that owns the default scope, the
/// persistent registry, and the context data box. The context-level factories,
/// global reads/writes, script evaluation, and data storage create or settle
/// engine references on the context default scope, so they live here rather
/// than in a core default; the actor also runs the storage teardown in its
/// isolated deinit, on the VM thread, so `JS_FreeContext` and the arena
/// settlement stay on the thread that owns the runtime.
public actor QJSContext: SwiftJavaScript.JSContext {
  public typealias VirtualMachine = QJSVirtualMachine
  public typealias InstantContext = QJSInstantContext
  public typealias Scope = QJSScope
  public typealias Value = QJSValue
  public typealias CallbackValue = QJSCallbackValue
  public typealias CallbackReturn = QJSCallbackReturn
  public typealias CallbackArguments = QJSCallbackArguments
  public typealias PersistentHandle = QJSPersistentHandle
  public typealias Arguments = QJSArguments
  public typealias ArrayBuffer = QJSArrayBuffer
  public typealias TypedArray = QJSTypedArray
  public typealias Class = QJSClass
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript

  /// The engine context identity every operation of this actor is addressed
  /// through. Package-internal: it is a handle, so it must not appear in a
  /// public signature.
  package nonisolated let driverContextHandle: QJSContextHandle
  public nonisolated let virtualMachine: QJSVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// The same identity as the shared driver interface, for package-internal
  /// seams (the scope witness and the contract tests' driver dispatch). This
  /// lets those call sites avoid naming the handle type.
  package nonisolated var runtimeDriver: any JSContextRuntimeDriver { driverContextHandle }

  private let storage: JSContextStorage<QJSContextHandle>

  public init() {
    self.init(virtualMachine: QJSVirtualMachine())
  }

  /// Engine access only on the VM thread: `makeContextHandle` creates the
  /// context there, and this initializer's data-box install is posted there
  /// too. `init` is synchronous: a caller on another thread waits for it, a
  /// caller already on the VM thread (inside another context's window) runs
  /// inline.
  public init(virtualMachine: QJSVirtualMachine) {
    guard let driverContextHandle = virtualMachine.makeContextHandle() else {
      preconditionFailure("QJSContext could not create a context handle from its runtime")
    }
    self.init(virtualMachine: virtualMachine, driverContextHandle: driverContextHandle)
  }

  package init(
    virtualMachine: QJSVirtualMachine,
    driverContextHandle: QJSContextHandle
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.driverContextHandle = driverContextHandle
    let storage = JSContextStorage<QJSContextHandle>(
      driverContextHandle: driverContextHandle,
      scheduler: virtualMachine.persistentCleanupScheduler,
      vmThread: virtualMachine.vmThread
    )
    self.storage = storage
    // The context data box exists from the end of init: synchronous scope
    // witnesses reach the registry through it, and the box remembers this
    // actor as its unretained owner.
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
    _ body: (borrowing QJSInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = QJSInstantContext(handle: driverContextHandle)
    return try body(instantContext)
  }

  public func makeScope() -> QJSScope {
    var scope = QJSScope(handle: driverContextHandle)
    scope.open()
    return scope
  }

  // MARK: - Ledger primitives
  //
  // Engine internals (package, never public): every context-level operation
  // below creates or settles an engine reference on the context default scope
  // through these two.

  package func adoptCreatedHandle(_ handle: consuming QJSOwnedValueHandle) -> QJSValue {
    QJSValue(
      handle: storage.defaultScope.trackCreatedHandle(handle),
      contextHandle: driverContextHandle
    )
  }

  package func anchorBorrowedHandle(_ handle: QJSValueHandle) -> QJSValue {
    QJSValue(
      handle: storage.defaultScope.claimAndTrackHandle(handle),
      contextHandle: driverContextHandle
    )
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> QJSValue {
    guard let handle = driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSValue {
    guard
      let handle = driverContextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: driverContextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNumber(_ value: Double) -> QJSValue {
    guard let handle = driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> QJSValue {
    guard let handle = driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNull() -> QJSValue {
    guard let handle = driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeUndefined() -> QJSValue {
    guard let handle = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeObject() -> QJSValue {
    guard let result = driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("QJSContext.makeObject failed")
    }
  }

  public func makeArray() -> QJSValue {
    guard let result = driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("QJSContext.makeArray failed")
    }
  }

  /// The creation reference is adopted by the context default scope, so the
  /// function outlives any single window.
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>
  ) -> QJSValue {
    guard
      let handle = driverContextHandle.makeFunctionValueHandle(named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    return adoptCreatedHandle(handle)
  }

  // MARK: - Persistent bindings

  public func makePersistentHandle(_ value: borrowing QJSValue) -> QJSPersistentHandle {
    precondition(
      value.contextHandle == driverContextHandle,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    return QJSPersistentHandle(
      identity: storage.persistentRegistry.mintIdentity(value.borrowHandle()),
      registry: storage.persistentRegistry
    )
  }

  public func resolve(_ handle: QJSPersistentHandle) -> QJSValue? {
    guard let borrowed = storage.persistentRegistry.borrowLive(handle.identity) else {
      return nil
    }
    return QJSValue(
      handle: storage.defaultScope.claimAndTrackHandle(borrowed),
      contextHandle: driverContextHandle
    )
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> QJSPropertyStringKey {
    guard let handle = driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return QJSPropertyStringKey(
      handle: handle,
      contextHandle: driverContextHandle,
      vmThread: ScopeStackRegistry<QJSContextHandle>.vmThread(for: driverContextHandle)
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    guard let handle = driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return QJSPreparedScript(
      handle: handle,
      contextHandle: driverContextHandle,
      vmThread: ScopeStackRegistry<QJSContextHandle>.vmThread(for: driverContextHandle)
    )
  }

  // MARK: - Global object

  public func globalObjectValue() -> QJSValue {
    guard let handle = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSContext.globalObjectValue could not get global object")
    }
    return QJSValue(handle: handle, contextHandle: driverContextHandle)
  }

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("QJSContext.getGlobalProperty could not get global object")
    }
    guard let result = driverContextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("QJSContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      driverContextHandle.releaseCreatedHandle(QJSOwnedValueHandle.adopting(handle))
      guard let undefined = driverContextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("QJSContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing QJSValue,
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
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    guard
      let result = driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("QJSContext.evaluateScript unexpectedly returned nil")
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
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }

  // MARK: - Identity

  public nonisolated static func == (lhs: QJSContext, rhs: QJSContext) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
