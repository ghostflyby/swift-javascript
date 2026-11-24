import SwiftJavaScript

/// The JavaScriptCore context actor.
///
/// Holds the engine handle, the VM it belongs to, and the shared
/// `JSContextStorage<JSCContextHandle>` that owns the default scope, the
/// persistent registry, and the context data box. The value factories, global
/// access and script evaluation are the `JSContext` protocol defaults; this
/// actor adds the engine-specific construction steps and runs the storage
/// teardown in its isolated deinit, on the VM thread.
public actor JSCContext: SwiftJavaScript.JSContext {
  public typealias ContextHandle = JSCContextHandle
  public typealias ValueHandle = JSCValueHandle
  public typealias OwnedValueHandle = JSCOwnedValueHandle
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
  public typealias ClassHandle = JSCClassHandle
  public typealias Class = JSCClass
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias PreparedScript = JSCPreparedScript

  public nonisolated let driverContextHandle: JSCContextHandle
  public nonisolated let virtualMachine: JSCVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

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

  public func adoptCreatedHandle(_ handle: consuming JSCOwnedValueHandle) -> JSCValue {
    JSCValue(
      handle: storage.defaultScope.trackCreatedHandle(handle),
      contextHandle: driverContextHandle
    )
  }

  public func anchorBorrowedHandle(_ handle: JSCValueHandle) -> JSCValue {
    JSCValue(
      handle: storage.defaultScope.claimAndTrackHandle(handle),
      contextHandle: driverContextHandle
    )
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

  // MARK: - Identity

  public nonisolated static func == (lhs: JSCContext, rhs: JSCContext) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
