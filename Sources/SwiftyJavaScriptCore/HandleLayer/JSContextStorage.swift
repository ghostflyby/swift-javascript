import SwiftJavaScript

/// The engine-agnostic lifetime state of a concrete context actor.
///
/// The engine actors (`JSCContext`, `QJSContext`) own one of these and keep
/// only their engine-specific wiring: this object holds the context's default
/// scope, the persistent-binding registry published into the context data
/// box, and the data box install/clear lifecycle. Everything that touches the
/// engine is addressed through the context handle, so the storage is
/// parameterized by that handle type and the two engines share the order in
/// which a context is assembled and torn down.
///
/// Ownership: the context actor owns the storage and calls `teardown()` from
/// its isolated deinit. The storage itself owns no engine reference beyond
/// the value-copy handle it was given — releasing that reference is part of
/// `teardown()`, in its documented position.
package final class JSContextStorage<ContextHandle: JSContextRuntimeDriver> {
  /// Non-retaining value copy of the context identity, like every other
  /// handle-copy holder in this layer.
  package let driverContextHandle: ContextHandle

  /// Context-lifetime default scope (design §3.6): the bottom frame of this
  /// context's scope stack. It is heap-resident, so it uses the explicit
  /// rooting policy: JSC values are protected on add and unprotected on
  /// drain; reference-counted engines rely on the creation reference the
  /// arena owns.
  package let defaultScope: ScopeCore<ContextHandle, JSExplicitRoots>

  /// Context-side persistent-binding registry (design §3.1). The same object
  /// is published into the context data box so synchronous scope witnesses
  /// can reach it; the storage keeps the authoritative strong reference.
  package let persistentRegistry: JSPersistentHandleRegistry<ContextHandle>

  private let vmThread: VMThread

  /// Push the default scope and build the registry. Runs on the thread that
  /// constructs the context actor; every engine call is still posted to the
  /// VM thread by the handle operations themselves.
  package init(
    driverContextHandle: ContextHandle,
    scheduler: any JSPersistentCleanupScheduler,
    vmThread: VMThread
  ) {
    self.driverContextHandle = driverContextHandle
    self.vmThread = vmThread
    self.persistentRegistry = JSPersistentHandleRegistry(
      contextHandle: driverContextHandle,
      scheduler: scheduler
    )
    let defaultScope = ScopeCore<ContextHandle, JSExplicitRoots>(handle: driverContextHandle)
    self.defaultScope = defaultScope
    ScopeStackRegistry.push(defaultScope, for: driverContextHandle)
  }

  /// Read or install the context data box on the VM thread, bind the owning
  /// context into it, publish the registry, and only then bind the context's
  /// VM thread.
  ///
  /// The order is load-bearing: the first install runs inline because the
  /// context has no VM-thread binding yet, and the binding installed last is
  /// what makes every later box swap route itself onto the VM thread
  /// (`swapContextDataStorageBox`).
  package func attachDataBox(bindingOwner owner: AnyObject) {
    let handle = driverContextHandle
    let box = vmThread.runAndWait { () -> JSContextDataStorageBox in
      if let existing = handle.contextDataStorageBox() {
        return existing
      }
      let box = JSContextDataStorageBox()
      handle.installContextDataStorageBox(box)
      return box
    }
    box.bindContextOwner(owner)
    box.setData(persistentRegistry, for: JSPersistentHandleRegistryKey<ContextHandle>.self)
    ScopeStackRegistry<ContextHandle>.bind(vmThread, for: driverContextHandle)
  }

  package func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  package func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }

  /// Settle everything the context owns, in the one order that keeps every
  /// engine call on a live context:
  ///
  /// 1. persistent bindings settle first — settlement needs a live engine
  ///    context and is deliberately independent of the default-scope ledger;
  /// 2. the default scope drains last, after every temporally nested scope
  ///    has closed (it is the stack bottom);
  /// 3. the box clear must run inline on the VM thread (it routes itself: the
  ///    binding is still in place) and must not be deferred past
  ///    `releaseReference()`;
  /// 4. the context reference is released;
  /// 5. the scope-stack pop drops the context's VM-thread binding last.
  package func teardown() {
    persistentRegistry.close()
    defaultScope.drain()
    driverContextHandle.installContextDataStorageBox(nil)
    _ = driverContextHandle.releaseReference()
    ScopeStackRegistry<ContextHandle>.pop(for: driverContextHandle)
  }
}
