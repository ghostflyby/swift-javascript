import SwiftJavaScript

/// The QuickJS context actor.
///
/// Holds the engine handle, the VM it belongs to, and the shared
/// `JSContextStorage<QJSContextHandle>` that owns the default scope, the
/// persistent registry, and the context data box. The value factories, global
/// access and script evaluation are the `JSContext` protocol defaults; this
/// actor adds the engine-specific construction steps and runs the storage
/// teardown in its isolated deinit, on the VM thread, so `JS_FreeContext` and
/// the arena settlement stay on the thread that owns the runtime.
public actor QJSContext: SwiftJavaScript.JSContext {
  public typealias ContextHandle = QJSContextHandle
  public typealias ValueHandle = QJSValueHandle
  public typealias OwnedValueHandle = QJSOwnedValueHandle
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
  public typealias ClassHandle = QJSClassHandle
  public typealias Class = QJSClass
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript

  public nonisolated let driverContextHandle: QJSContextHandle
  public nonisolated let virtualMachine: QJSVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

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

  public func adoptCreatedHandle(_ handle: consuming QJSOwnedValueHandle) -> QJSValue {
    QJSValue(
      handle: storage.defaultScope.trackCreatedHandle(handle),
      contextHandle: driverContextHandle
    )
  }

  public func anchorBorrowedHandle(_ handle: QJSValueHandle) -> QJSValue {
    QJSValue(
      handle: storage.defaultScope.claimAndTrackHandle(handle),
      contextHandle: driverContextHandle
    )
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

  // MARK: - Identity

  public nonisolated static func == (lhs: QJSContext, rhs: QJSContext) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
