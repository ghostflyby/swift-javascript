import Dispatch
import SwiftJavaScript
import Synchronization

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// A weak, Sendable view of a context actor for non-actor owners (persistent
/// handles, self-owning inputs): their deinit must not keep the context alive.
final class QJSContextReference: @unchecked Sendable {
  weak var value: QJSContext?

  init(_ value: QJSContext) {
    self.value = value
  }
}

/// The QuickJS context actor.
///
/// Engine state is created during `init` on the VM's executor: the
/// synchronous initializer blocks until it exists (or runs inline when the
/// caller already is the executor), and the `JSInitMode.nonblocking` form
/// awaits instead. The actor runs the storage teardown in its isolated
/// deinit, on the same executor.
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
  public typealias ClassPropertyNameAccumulator = Never

  /// The raw QuickJS context, created during init on the VM executor and never
  /// reassigned. Package-internal: it must not appear in a public signature.
  private nonisolated(unsafe) var engineContext: OpaquePointer?

  /// The engine context pointer, valid from the end of `init`.
  package nonisolated var contextRef: OpaquePointer {
    engineContext!
  }
  public nonisolated let virtualMachine: QJSVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// The context default scope, created with the engine state.
  private nonisolated(unsafe) var defaultScope: QJSScopeCore!
  /// The persistent-binding table, created with the engine state.
  private nonisolated(unsafe) var persistentBindings: QJSPersistentBindings!

  /// Engine references owned by self-owning inputs, keyed by token. The
  /// context is the reverse owner: whatever is still registered at teardown
  /// is released there, so an input that outlives its context leaks nothing.
  private struct InputRecord {
    let atom: JSAtom?
    let contextBits: UInt
  }
  private nonisolated let inputRecords = Mutex<[UInt64: InputRecord]>([:])
  private nonisolated let inputCounter = Atomic<UInt64>(0)

  @available(*, noasync)
  public init() {
    self.init(virtualMachine: QJSVirtualMachine())
  }

  public init(_ mode: JSInitMode) async {
    let virtualMachine = await QJSVirtualMachine(.nonblocking)
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    await openEngine()
  }

  /// Build the engine state during init, on the VM executor. A caller that
  /// already is that executor runs the work inline; otherwise it hops through
  /// a temporary `JSExecutorHop`: the synchronous form blocks this thread, the
  /// `JSInitMode.nonblocking` form awaits.
  @available(*, noasync)
  public init(virtualMachine: QJSVirtualMachine) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    openEngineSynchronously()
  }

  public init(virtualMachine: QJSVirtualMachine, _ mode: JSInitMode) async {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    await openEngine()
  }

  private nonisolated func openEngineSynchronously() {
    if virtualMachine.isOnVMExecutor() {
      makeEngineStateOnExecutor()
      return
    }
    // The VM's executor is a task executor, so the job is enqueued
    // immediately (SE-0417) and needs no cooperative-pool thread.
    let done = DispatchSemaphore(value: 0)
    scheduleOnTaskExecutor(virtualMachine.executor) { [self] in
      makeEngineStateOnExecutor()
      done.signal()
    }
    done.wait()
  }

  private nonisolated func openEngine() async {
    if virtualMachine.isOnVMExecutor() {
      makeEngineStateOnExecutor()
      return
    }
    await runOnTaskExecutor(virtualMachine.executor) { [self] in
      makeEngineStateOnExecutor()
    }
  }

  /// Create the context, default scope and binding table. Engine work: the
  /// caller runs on the VM executor.
  private nonisolated func makeEngineStateOnExecutor() {
    guard engineContext == nil else { return }
    guard let contextBits = virtualMachine.makeContextOnExecutor(),
      let contextRef = OpaquePointer(bitPattern: contextBits)
    else {
      preconditionFailure("QJSContext could not create a context from its runtime")
    }
    let defaultScope = QJSScopeCore(contextRef: contextRef)
    let persistentBindings = QJSPersistentBindings(contextRef: contextRef)
    QJSScopeStacks.push(defaultScope)

    // The context data box exists before any engine call can run user code:
    // synchronous scope witnesses reach the binding table through it, and the
    // box remembers this actor as its unretained owner (raw callbacks).
    let box = JSContextDataStorageBox()
    quickJSInstallContextDataStorageBox(box, in: contextRef)
    box.bindContextOwner(self)
    box.setData(persistentBindings, for: QJSPersistentBindingsKey.self)

    self.engineContext = contextRef
    self.defaultScope = defaultScope
    self.persistentBindings = persistentBindings
    QJSScopeStacks.bind(self, for: contextRef)
  }

  /// Register a self-owning input's engine references with the reverse owner.
  /// Callable from any thread: the reference bits are captured before the
  /// input becomes reachable.
  package nonisolated func registerInput(atom: JSAtom?, contextBits: UInt) -> UInt64 {
    let token = inputCounter.wrappingAdd(1, ordering: .relaxed).newValue
    inputRecords.withLock {
      $0[token] = InputRecord(atom: atom, contextBits: contextBits)
    }
    return token
  }

  /// Take a registered input's references back and release them. Engine work:
  /// the caller schedules this on the VM executor.
  package nonisolated func releaseInput(_ token: UInt64) {
    guard let record = inputRecords.withLock({ $0.removeValue(forKey: token) }) else {
      return
    }
    releaseInputRecord(record)
  }

  private nonisolated func releaseInputRecord(_ record: InputRecord) {
    guard let context = OpaquePointer(bitPattern: record.contextBits) else { return }
    if let atom = record.atom {
      JS_FreeAtom(context, atom)
    }
    JS_FreeContext(context)
  }

  /// Free one released persistent binding. Engine work: the caller schedules
  /// this on the VM executor.
  package nonisolated func freePersistentValue(_ value: CQuickJSValue) {
    let contextRef = contextRef
    JS_FreeValue(contextRef, value)
  }

  /// Isolated deinit (SE-0371): runs on the actor's VM executor, so the
  /// engine-touching teardown never executes on a foreign thread.
  isolated deinit {
    guard let contextRef = engineContext else { return }
    persistentBindings.close()
    defaultScope.drain()
    quickJSInstallContextDataStorageBox(nil, in: contextRef)
    // Inputs that outlived the context: the reverse owner releases what they
    // still hold before the context reference itself goes away.
    let records = inputRecords.withLock { records -> [InputRecord] in
      let all = Array(records.values)
      records.removeAll()
      return all
    }
    for record in records {
      releaseInputRecord(record)
    }
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
    guard let created = quickJSMakeString(value, in: contextRef) else {
      preconditionFailure("makeString failed")
    }
    return adoptCreated(created)
  }

  public func makeString(from key: borrowing QJSPropertyStringKey) -> QJSValue {
    guard
      let created = quickJSMakeStringValue(
        fromAtom: key.borrowAtom(in: contextRef),
        in: contextRef
      )
    else {
      preconditionFailure("makeStringValue failed")
    }
    return adoptCreated(created)
  }

  public func makeNumber(_ value: Double) -> QJSValue {
    guard let created = quickJSMakeNumber(value, in: contextRef) else {
      preconditionFailure("makeNumber failed")
    }
    return adoptCreated(created)
  }

  public func makeBoolean(_ value: Bool) -> QJSValue {
    guard let created = quickJSMakeBoolean(value, in: contextRef) else {
      preconditionFailure("makeBoolean failed")
    }
    return adoptCreated(created)
  }

  public func makeNull() -> QJSValue {
    guard let created = quickJSMakeNull(in: contextRef) else {
      preconditionFailure("makeNull failed")
    }
    return adoptCreated(created)
  }

  public func makeUndefined() -> QJSValue {
    guard let created = quickJSMakeUndefined(in: contextRef) else {
      preconditionFailure("makeUndefined failed")
    }
    return adoptCreated(created)
  }

  public func makeObject() -> QJSValue {
    guard let result = quickJSMakeObjectResult(in: contextRef) else {
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
    guard let result = quickJSMakeArrayResult(in: contextRef) else {
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
      let created = quickJSMakeFunction(
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
      registry: persistentBindings,
      context: self
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
    guard let atom = quickJSMakePropertyStringAtom(value, in: contextRef) else {
      preconditionFailure("makePropertyStringAtom could not create a key")
    }
    return QJSPropertyStringKey(
      atom: atom,
      contextRef: contextRef,
      context: self
    )
  }

  public func prepareScript(_ source: String) -> QJSPreparedScript {
    return QJSPreparedScript(
      source: source,
      contextRef: contextRef,
      context: self
    )
  }

  // MARK: - Global object

  public func globalObjectValue() -> QJSValue {
    guard let global = quickJSGlobalObjectValue(contextRef) else {
      preconditionFailure("QJSContext.globalObjectValue could not get global object")
    }
    return QJSValue(value: global, contextRef: contextRef)
  }

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> QJSValue {
    guard let global = quickJSGlobalObjectValue(contextRef) else {
      preconditionFailure("QJSContext.getGlobalProperty could not get global object")
    }
    guard let result = quickJSGetStaticStringProperty(key, on: global, in: contextRef) else {
      preconditionFailure("QJSContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let created):
      return adoptCreated(created)
    case .exception(let thrown):
      JS_FreeValue(contextRef, thrown)
      guard let undefined = quickJSMakeUndefined(in: contextRef) else {
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
    guard let global = quickJSGlobalObjectValue(contextRef) else { return }
    _ = quickJSSetStaticStringProperty(
      key,
      on: global,
      to: value.value,
      in: contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = quickJSGlobalObjectValue(contextRef) else { return }
    _ = quickJSDeleteStaticStringProperty(key, on: global, in: contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = quickJSGlobalObjectValue(contextRef) else {
      return false
    }
    return quickJSHasStaticStringProperty(key, on: global, in: contextRef) ?? false
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing QJSPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QJSValue> {
    let result = quickJSEvaluateScript(
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
    quickJSContextDataStorageBox(in: contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    return quickJSContextDataStorageBox(in: contextRef)?.data(for: key) ?? K.defaultValue
  }

  /// Package-internal data-box seam used by the cross-engine contract tests.
  package nonisolated func contextDataStorageBox() -> JSContextDataStorageBox? {
    quickJSContextDataStorageBox(in: contextRef)
  }

  /// Installs are engine mutations; this stays a hop target for the tests
  /// that swap the box from a foreign thread.
  package func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) async {
    quickJSInstallContextDataStorageBox(storage, in: contextRef)
  }

  // MARK: - Identity

  public nonisolated static func == (lhs: QJSContext, rhs: QJSContext) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
