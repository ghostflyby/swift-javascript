public actor JSContext<E: JSContextEngine> {
  nonisolated package let driverContextHandle: E.ContextHandle
  /// Nonisolated: an immutable, Sendable identity of the owning VM — needed
  /// by callers right after dropping the context (e.g. the FIFO sentinel
  /// pattern for the asynchronously scheduled isolated deinit).
  nonisolated public let virtualMachine: JSVirtualMachine<E>
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  /// Context-lifetime default scope (design §3.6): the bottom frame of this
  /// context's scope stack. Its arena is heap-resident, so it uses the
  /// explicit-rooting policy (§3.7): JSC values are protected on add and
  /// unprotected on drain; reference-counted engines rely on the creation
  /// reference the arena owns.
  private let defaultScope: ScopeCore<E, JSExplicitRoots>

  /// Context-side persistent-binding registry (design §3.1). Lifetime is
  /// owned here; the same object is published into the context data storage
  /// box so synchronous scope witnesses can reach it.
  package let persistentRegistry: JSPersistentHandleRegistry<E>

  public init() {
    self.init(virtualMachine: JSVirtualMachine<E>())
  }

  public init(virtualMachine: JSVirtualMachine<E>) {
    guard
      let driverContextHandle = E.makeBorrowedContextHandleFromRuntime(
        in: virtualMachine.driverRuntimeHandle)
    else {
      preconditionFailure("JSContext could not create context handle from runtime")
    }

    self.init(virtualMachine: virtualMachine, driverContextHandle: driverContextHandle)
    let storage =
      driverContextHandle.contextDataStorageBox()
      ?? {
        let box = JSContextDataStorageBox()
        driverContextHandle.installContextDataStorageBox(box)
        return box
      }()
    storage.bindContextOwner(self)
    // Publish the same registry object into the box: callbacks and `JSScope`
    // can only reach it synchronously through the box (design §3.1). The
    // context keeps the authoritative strong reference, so an external box
    // clear only removes this access path.
    storage.setData(persistentRegistry, for: JSPersistentHandleRegistryKey<E>.self)
    // Bind after the install above. A context's `init` runs entirely on its
    // caller's thread (the documented bootstrap exception: it issues
    // `JS_NewContext` there too), so the first box install stays inline and
    // synchronous with `init`. From here on, storage-box swaps are routed to
    // the VM thread (`swapContextDataStorageBox`).
    ScopeStackRegistry<E>.bind(virtualMachine.vmThread, for: driverContextHandle)
  }

  package init(
    virtualMachine: JSVirtualMachine<E>,
    driverContextHandle: E.ContextHandle
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.driverContextHandle = driverContextHandle
    self.persistentRegistry = JSPersistentHandleRegistry(
      contextHandle: driverContextHandle,
      scheduler: virtualMachine.persistentCleanupScheduler
    )
    let defaultScope = ScopeCore<E, JSExplicitRoots>(handle: driverContextHandle)
    self.defaultScope = defaultScope
    ScopeStackRegistry.push(defaultScope, for: driverContextHandle)
  }

  /// Isolated deinit (SE-0371, experimental `IsolatedDeinit`): runs on the
  /// actor's dedicated VM thread, so the engine-touching teardown below —
  /// default-scope drain (`JSValueUnprotect` / `JS_FreeValue`), stack pop,
  /// storage box release, context handle release — never executes on a
  /// foreign thread (the registered cross-thread risk when a VM is shared
  /// by multiple contexts). The executor fallback (dispatching teardown to
  /// the VM executor from a nonisolated deinit) was evaluated and not
  /// needed.
  isolated deinit {
    // Persistent bindings settle first (design §4.1): settlement needs a live
    // engine context, and this must run before `releaseReference()`. It is
    // deliberately independent of the default-scope drain: the two ledgers
    // never reference each other (§7.4).
    persistentRegistry.close()
    // The default scope is the stack bottom: drain it last, after every
    // temporally nested scope has closed, then pop its frame.
    defaultScope.drain()
    ScopeStackRegistry<E>.pop(for: driverContextHandle)
    // The pop above dropped this context's VM-thread binding with its last
    // frame, so the box clear below is inline — it must be: a routed
    // (deferred) clear could only run after this body, i.e. after
    // `releaseReference()`.
    driverContextHandle.installContextDataStorageBox(nil)
    _ = driverContextHandle.releaseReference()
  }

  /// The default-scope arena frame: the anchor for actor-side persistent
  /// handle resolution (design §5.1/§7.2).
  var defaultScopeFrame: ScopeFrame<E> { defaultScope.frame }
}

extension JSContext {
  public func withIsolatedGlobalObject<R: Sendable>(
    _ body:
      @Sendable (
        isolated JSContext<E>,
        borrowing JSValue<E>
      ) -> R
  ) -> R {
    withGlobalObject { globalObject in
      body(self, globalObject)
    }
  }

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type = K.self) {
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type = K.self) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSInstantContext<E>) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = JSInstantContext<E>(handle: driverContextHandle)
    return try body(instantContext)
  }

  /// Open a manual `JSScope` nested on this context's scope stack (design
  /// §3.4): its frame is the context's top frame until the returned scope
  /// leaves scope.
  ///
  /// The public construction path for `JSScope`. The factory is
  /// actor-isolated and `JSScope` is neither `Copyable` nor `Sendable`, so
  /// the scope is born, used and drained inside this context's isolation —
  /// on the VM thread — which is the witness guarantee its mint/resolve
  /// entry points rely on (`docs/PERSISTENT_HANDLE_DESIGN.md` §3.5).
  public func makeScope() -> JSScope<E> {
    var scope = JSScope<E>(handle: driverContextHandle)
    scope.open()
    return scope
  }

  public func makeString(_ value: String) -> JSValue<E> {
    defaultScope.makeJSValue(defaultScope.makeString(value))
  }

  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSValue<E> {
    defaultScope.makeJSValue(
      defaultScope.makeString(from: key.borrowHandle(in: driverContextHandle))
    )
  }

  public func makePropertyStringKey(_ value: String) -> JSPropertyStringKey<E> {
    withInstantContext { instantContext in
      instantContext.makePropertyStringKey(value)
    }
  }

  public func prepareScript(_ source: String) -> JSPreparedScript<E> {
    withInstantContext { instantContext in
      instantContext.prepareScript(source)
    }
  }

  public func makeNumber(_ value: Double) -> JSValue<E> {
    defaultScope.makeJSValue(defaultScope.makeNumber(value))
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSValue<E> {
    makeNumber(Double(value))
  }

  public func makeBoolean(_ value: Bool) -> JSValue<E> {
    defaultScope.makeJSValue(defaultScope.makeBoolean(value))
  }

  public func makeNull() -> JSValue<E> {
    defaultScope.makeJSValue(defaultScope.makeNull())
  }

  public func makeUndefined() -> JSValue<E> {
    defaultScope.makeJSValue(defaultScope.makeUndefined())
  }

  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    body(defaultScope.globalObjectValue())
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, with: attributes)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) where E: JSValueConversionEngine {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, using: converter, with: attributes)
    }
  }

  public func getGlobalProperty(forKey key: StaticString) -> JSValue<E> {
    defaultScope.getGlobalPropertyValue(forKey: key)
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type
  ) -> C.SwiftType where E: JSValueConversionEngine {
    withInstantContext { instantContext in
      instantContext.getGlobalProperty(forKey: key, using: converter)
    }
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    withInstantContext { instantContext in
      instantContext.deleteGlobalProperty(forKey: key)
    }
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    withInstantContext { instantContext in
      instantContext.hasGlobalProperty(key)
    }
  }

  public func makeObject() -> JSValue<E> {
    switch defaultScope.makeObject() {
    case .value(let callbackValue):
      return defaultScope.makeJSValue(callbackValue)
    case .exception:
      preconditionFailure("makeObject failed")
    }
  }

  public func makeArray() -> JSValue<E> {
    switch defaultScope.makeArray() {
    case .value(let callbackValue):
      return defaultScope.makeJSValue(callbackValue)
    case .exception:
      preconditionFailure("makeArray failed")
    }
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    defaultScope.makeFunctionValue(named: name, callback: callback)
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback<E>
  ) where E.Engine == E {
    withInstantContext { instantContext in
      instantContext.installGlobalFunction(named: name, with: attributes, callback: callback)
    }
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    guard let preparedHandle = driverContextHandle.makePreparedScriptHandle(script) else {
      preconditionFailure("JSContext.evaluateScript could not prepare script")
    }
    let prepared = JSPreparedScript<E>(handle: preparedHandle, context: driverContextHandle)
    return defaultScope.evaluateScriptValue(
      prepared,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  public func evaluateScript(
    _ script: borrowing JSPreparedScript<E>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    defaultScope.evaluateScriptValue(
      script,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }
}

extension JSContext: Equatable where E.ContextHandle: Equatable {
  nonisolated public static func == (lhs: JSContext<E>, rhs: JSContext<E>) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }
}

extension JSContext: Hashable where E.ContextHandle: Hashable {
  nonisolated public func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
