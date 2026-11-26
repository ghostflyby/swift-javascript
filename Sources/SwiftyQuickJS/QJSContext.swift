import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// The QuickJS context actor.
///
/// Holds the raw `contextRef`, the VM it belongs to, its default scope,
/// concrete persistent-binding table, and VM thread. The context-level
/// factories, global reads/writes, script evaluation, and data storage create
/// or settle engine references on the context default scope, so they live here
/// rather than in a core default; the actor also runs the storage teardown in
/// its isolated deinit, on the VM thread.
public actor QJSContext: SwiftJavaScript.JSContext {
  public typealias VirtualMachine = QJSVirtualMachine
  public typealias InstantContext = QJSInstantContext
  public typealias Scope = QJSScope
  public typealias Value = QJSValue
  public typealias CallbackReturn = QJSCallbackReturn
  public typealias CallbackArguments = QJSCallbackArguments
  public typealias PersistentHandle = QJSPersistentHandle
  public typealias Arguments = QJSArguments
  public typealias ArrayBuffer = QJSArrayBuffer
  public typealias TypedArray = QJSTypedArray
  public typealias Class = QJSClass
  public typealias PropertyStringKey = QJSPropertyStringKey
  public typealias PreparedScript = QJSPreparedScript

  /// The raw QuickJS context every operation of this actor is addressed
  /// through. Package-internal: it must not appear in a public signature.
  nonisolated(unsafe) let contextRef: OpaquePointer
  public nonisolated let virtualMachine: QJSVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  private let defaultScope: QJSScopeCore
  private let persistentBindings: QJSPersistentBindings
  private let vmThread: VMThread

  public init() {
    self.init(virtualMachine: QJSVirtualMachine())
  }

  /// Engine access only on the VM thread: `makeContext` creates the context
  /// there, and this initializer's data-box install is posted there too.
  /// `init` is synchronous: a caller on another thread waits for it, a caller
  /// already on the VM thread (inside another context's window) runs inline.
  public init(virtualMachine: QJSVirtualMachine) {
    guard let contextRef = virtualMachine.makeContext() else {
      preconditionFailure("QJSContext could not create a context from its runtime")
    }
    self.init(virtualMachine: virtualMachine, contextRef: contextRef)
  }

  package init(
    virtualMachine: QJSVirtualMachine,
    contextRef: OpaquePointer
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.contextRef = contextRef
    self.vmThread = virtualMachine.vmThread
    let defaultScope = QJSScopeCore(contextRef: contextRef)
    self.defaultScope = defaultScope
    let persistentBindings = QJSPersistentBindings(
      contextRef: contextRef,
      vmThread: virtualMachine.vmThread
    )
    self.persistentBindings = persistentBindings
    QJSScopeStacks.push(defaultScope)

    // The context data box exists from the end of init: synchronous scope
    // witnesses reach the binding table through it, and the box remembers
    // this actor as its unretained owner (used by raw callback contexts).
    let box = JSContextDataStorageBox()
    let vmThread = virtualMachine.vmThread
    let contextBits = UInt(bitPattern: contextRef)
    vmThread.runAndWait {
      guard let context = OpaquePointer(bitPattern: contextBits) else { return }
      QJSEngine.installContextDataStorageBox(box, in: context)
      box.bindContextOwner(self)
      box.setData(persistentBindings, for: QJSPersistentBindingsKey.self)
    }
    QJSScopeStacks.bind(vmThread, for: contextRef)
  }

  /// Isolated deinit (SE-0371): runs on the actor's dedicated VM thread, so
  /// the engine-touching teardown never executes on a foreign thread.
  isolated deinit {
    persistentBindings.close()
    defaultScope.drain()
    let contextBits = UInt(bitPattern: contextRef)
    let vmThread = self.vmThread
    vmThread.runAndWait {
      guard let context = OpaquePointer(bitPattern: contextBits) else { return }
      QJSEngine.installContextDataStorageBox(nil, in: context)
    }
    quickJSUpdateStackTop(contextRef)
    JS_FreeContext(contextRef)
    QJSScopeStacks.pop(for: contextRef)
  }

  // MARK: - Synchronous scopes

  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing QJSInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = QJSInstantContext(contextRef: contextRef)
    return try body(instantContext)
  }

  public func makeScope() -> QJSScope {
    var scope = QJSScope(contextRef: contextRef)
    scope.open()
    return scope
  }

  // MARK: - Ledger primitives
  //
  // Engine internals (package, never public): every context-level operation
  // below creates or settles an engine reference on the context default scope
  // through these two.

  package func adoptCreated(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: defaultScope.trackCreated(value), contextRef: contextRef)
  }

  package func anchorBorrowed(_ value: CQuickJSValue) -> QJSValue {
    QJSValue(value: defaultScope.claimAndTrack(value), contextRef: contextRef)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> QJSValue {
    guard let created = QJSEngine.makeString(value, in: contextRef) else {
      preconditionFailure("makeString failed")
    }
    return adoptCreated(created)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSValue {
    guard
      let created = QJSEngine.makeStringValue(
        fromAtom: key.borrowAtom(in: contextRef),
        in: contextRef
      )
    else {
      preconditionFailure("makeStringValue failed")
    }
    return adoptCreated(created)
  }

  public func makeNumber(_ value: Double) -> QJSValue {
    guard let created = QJSEngine.makeNumber(value, in: contextRef) else {
      preconditionFailure("makeNumber failed")
    }
    return adoptCreated(created)
  }

  public func makeBoolean(_ value: Bool) -> QJSValue {
    guard let created = QJSEngine.makeBoolean(value, in: contextRef) else {
      preconditionFailure("makeBoolean failed")
    }
    return adoptCreated(created)
  }

  public func makeNull() -> QJSValue {
    guard let created = QJSEngine.makeNull(in: contextRef) else {
      preconditionFailure("makeNull failed")
    }
    return adoptCreated(created)
  }

  public func makeUndefined() -> QJSValue {
    guard let created = QJSEngine.makeUndefined(in: contextRef) else {
      preconditionFailure("makeUndefined failed")
    }
    return adoptCreated(created)
  }

  public func makeObject() -> QJSValue {
    guard let result = QJSEngine.makeObjectResult(in: contextRef) else {
      preconditionFailure("makeObjectResult failed")
    }
    switch consume result {
    case .value(let created):
      return adoptCreated(created)
    case .exception:
      preconditionFailure("QJSContext.makeObject failed")
    }
  }

  public func makeArray() -> QJSValue {
    guard let result = QJSEngine.makeArrayResult(in: contextRef) else {
      preconditionFailure("makeArrayResult failed")
    }
    switch consume result {
    case .value(let created):
      return adoptCreated(created)
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
      let created = QJSEngine.makeFunction(
        named: name,
        callback: callback,
        in: contextRef
      )
    else {
      preconditionFailure("makeFunction could not create a function")
    }
    return adoptCreated(created)
  }

  // MARK: - Persistent bindings

  public func makePersistentHandle(_ value: borrowing QJSValue) -> QJSPersistentHandle {
    precondition(
      value.contextRef == contextRef,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    return QJSPersistentHandle(
      identity: persistentBindings.mint(value.value),
      registry: persistentBindings
    )
  }

  public func resolve(_ handle: QJSPersistentHandle) -> QJSValue? {
    guard let borrowed = persistentBindings.borrowLive(handle.identity) else {
      return nil
    }
    return anchorBorrowed(borrowed)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> QJSPropertyStringKey {
    guard let atom = QJSEngine.makePropertyStringAtom(value, in: contextRef) else {
      preconditionFailure("makePropertyStringAtom could not create a key")
    }
    return QJSPropertyStringKey(
      atom: atom,
      contextRef: contextRef,
      vmThread: vmThread
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    QJSPreparedScript(
      source: source,
      contextRef: contextRef,
      vmThread: vmThread
    )
  }

  // MARK: - Global object

  public func globalObjectValue() -> QJSValue {
    guard let global = QJSEngine.globalObjectValue(contextRef) else {
      preconditionFailure("QJSContext.globalObjectValue could not get global object")
    }
    return QJSValue(value: global, contextRef: contextRef)
  }

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = QJSEngine.globalObjectValue(contextRef) else {
      preconditionFailure("QJSContext.getGlobalProperty could not get global object")
    }
    guard let result = QJSEngine.getStaticStringProperty(key, on: global, in: contextRef) else {
      preconditionFailure("QJSContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let created):
      return adoptCreated(created)
    case .exception(let thrown):
      quickJSUpdateStackTop(contextRef)
      JS_FreeValue(contextRef, thrown)
      guard let undefined = QJSEngine.makeUndefined(in: contextRef) else {
        preconditionFailure("QJSContext could not create an undefined value")
      }
      return adoptCreated(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing QJSValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = QJSEngine.globalObjectValue(contextRef) else { return }
    _ = QJSEngine.setStaticStringProperty(
      key,
      on: global,
      to: value.value,
      in: contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = QJSEngine.globalObjectValue(contextRef) else { return }
    _ = QJSEngine.deleteStaticStringProperty(key, on: global, in: contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = QJSEngine.globalObjectValue(contextRef) else {
      return false
    }
    return QJSEngine.hasStaticStringProperty(key, on: global, in: contextRef) ?? false
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let result = QJSEngine.evaluateScript(
      script.borrowSource(in: contextRef),
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber,
      in: contextRef
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
    QJSEngine.contextDataStorageBox(in: contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    QJSEngine.contextDataStorageBox(in: contextRef)?.data(for: key) ?? K.defaultValue
  }

  /// Package-internal data-box seam used by the cross-engine contract tests.
  package nonisolated func contextDataStorageBox() -> JSContextDataStorageBox? {
    QJSEngine.contextDataStorageBox(in: contextRef)
  }

  package nonisolated func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    let contextBits = UInt(bitPattern: contextRef)
    if let vmThread = QJSScopeStacks.vmThread(for: contextRef) {
      vmThread.perform {
        guard let contextRef = OpaquePointer(bitPattern: contextBits) else {
          return
        }
        QJSEngine.installContextDataStorageBox(storage, in: contextRef)
      }
    } else {
      QJSEngine.installContextDataStorageBox(storage, in: contextRef)
    }
  }

  // MARK: - Identity

  public nonisolated static func == (lhs: QJSContext, rhs: QJSContext) -> Bool {
    lhs.contextRef == rhs.contextRef
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(UInt(bitPattern: contextRef))
  }
}
