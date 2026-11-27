import Dispatch
import JavaScriptCore
import SwiftJavaScript
import Synchronization

/// A weak, Sendable view of a context actor for non-actor owners (persistent
/// handles, self-owning inputs): their deinit must not keep the context alive.
final class JSCContextReference: @unchecked Sendable {
  weak var value: JSCContext?

  init(_ value: JSCContext) {
    self.value = value
  }
}

/// The JavaScriptCore context actor.
///
/// Holds the raw `JSGlobalContextRef`, the VM it belongs to, its default
/// scope, concrete persistent-binding table, and VM thread. The context-level
/// factories, global reads/writes, script evaluation, and data storage create
/// or settle engine references on the context default scope, so they live here
/// rather
/// than in a core default; the actor also runs the storage teardown in its
/// isolated deinit, on the VM thread.
public actor JSCContext: SwiftJavaScript.JSContext {
  public typealias VirtualMachine = JSCVirtualMachine
  public typealias InstantContext = JSCInstantContext
  public typealias Scope = JSCScope
  public typealias Value = JSCValue
  public typealias CallbackReturn = JSCCallbackReturn
  public typealias CallbackArguments = JSCCallbackArguments
  public typealias PersistentHandle = JSCPersistentHandle
  public typealias Arguments = JSCArguments
  public typealias ArrayBuffer = JSCArrayBuffer
  public typealias TypedArray = JSCTypedArray
  public typealias Class = JSCClass
  public typealias PropertyStringKey = JSCPropertyStringKey
  public typealias PreparedScript = JSCPreparedScript

  /// The raw JavaScriptCore context handle, created during init on the VM
  /// executor and never reassigned. Package-internal: it must not appear in a
  /// public signature.
  private nonisolated(unsafe) var engineContext: JSGlobalContextRef?

  /// The engine context handle, valid from the end of `init`.
  package nonisolated var contextRef: JSGlobalContextRef {
    engineContext!
  }
  /// Cached `Object.keys` wrapper, created before any user script can patch
  /// `Object.keys`. Immutable and only read by engine-side property queries.
  package nonisolated(unsafe) var propertyNamesFunction: JSObjectRef?
  public nonisolated let virtualMachine: JSCVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// The context default scope, created with the engine state.
  private nonisolated(unsafe) var defaultScope: JSCScopeCore!
  /// The persistent-binding table, created with the engine state.
  private nonisolated(unsafe) var persistentBindings: JSCPersistentBindings!

  /// Engine references owned by self-owning inputs, keyed by token. The
  /// context is the reverse owner: whatever is still registered at teardown
  /// is released there, so an input that outlives its context leaks nothing.
  private struct InputRecord {
    let stringBits: UInt
    let contextBits: UInt
  }
  private nonisolated let inputRecords = Mutex<[UInt64: InputRecord]>([:])
  private nonisolated let inputCounter = Atomic<UInt64>(0)

  @available(*, noasync)
  public init() {
    let virtualMachine = JSCVirtualMachine()
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    openEngineSynchronously()
  }

  public init(_ mode: JSInitMode) async {
    let virtualMachine = await JSCVirtualMachine(.nonblocking)
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    await openEngine()
  }

  /// Build the engine state during init, on the VM executor. A caller that
  /// already is that executor runs the work inline; otherwise it hops through
  /// a temporary `JSExecutorHop`: the synchronous form blocks this thread, the
  /// `JSInitMode.nonblocking` form awaits.
  @available(*, noasync)
  public init(virtualMachine: JSCVirtualMachine) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    openEngineSynchronously()
  }

  public init(virtualMachine: JSCVirtualMachine, _ mode: JSInitMode) async {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    await openEngine()
  }

  private nonisolated func openEngineSynchronously() {
    if virtualMachine.isOnVMExecutor() {
      makeEngineStateOnExecutor()
      return
    }
    let done = DispatchSemaphore(value: 0)
    if let taskExecutor = virtualMachine.executor as? any TaskExecutor {
      scheduleOnTaskExecutor(taskExecutor) { [self] in
        makeEngineStateOnExecutor()
        done.signal()
      }
    } else {
      let hop = JSExecutorHop(executor: virtualMachine.executor)
      Task { [self] in
        await hop.run {
          makeEngineStateOnExecutor()
        }
        done.signal()
      }
    }
    done.wait()
  }

  private nonisolated func openEngine() async {
    if virtualMachine.isOnVMExecutor() {
      makeEngineStateOnExecutor()
      return
    }
    if let taskExecutor = virtualMachine.executor as? any TaskExecutor {
      await runOnTaskExecutor(taskExecutor) { [self] in
        makeEngineStateOnExecutor()
      }
      return
    }
    let hop = JSExecutorHop(executor: virtualMachine.executor)
    await hop.run { [self] in
      makeEngineStateOnExecutor()
    }
  }

  /// Create the context, default scope and binding table. Engine work: the
  /// caller runs on the VM executor.
  private nonisolated func makeEngineStateOnExecutor() {
    guard engineContext == nil else { return }
    guard let contextBits = virtualMachine.makeContextHandleOnExecutor(),
      let contextRef = JSGlobalContextRef(bitPattern: contextBits)
    else {
      preconditionFailure("JSCContext could not create a context from its runtime")
    }
    let defaultScope = JSCScopeCore(contextRef: contextRef, rootsArenaValues: true)
    let persistentBindings = JSCPersistentBindings(contextRef: contextRef)
    let propertyNamesFunction = JSCEngine.makePropertyNamesFunction(in: contextRef)
    JSCScopeStacks.push(defaultScope)

    // The context data box exists before any engine call can run user code:
    // synchronous scope witnesses reach the binding table through it, and the
    // box remembers this actor as its unretained owner (raw callbacks).
    let box = JSContextDataStorageBox()
    JSCEngine.installContextDataStorageBox(box, in: contextRef)
    box.bindContextOwner(self)
    box.setData(persistentBindings, for: JSCPersistentBindingsKey.self)

    self.engineContext = contextRef
    self.defaultScope = defaultScope
    self.persistentBindings = persistentBindings
    self.propertyNamesFunction = propertyNamesFunction
    JSCScopeStacks.bind(self, for: contextRef)
  }

  /// Register a self-owning input's engine references with the reverse owner.
  /// Callable from any thread: the reference bits are captured before the
  /// input becomes reachable.
  package nonisolated func registerInput(stringBits: UInt, contextBits: UInt) -> UInt64 {
    let token = inputCounter.wrappingAdd(1, ordering: .relaxed).newValue
    inputRecords.withLock {
      $0[token] = InputRecord(stringBits: stringBits, contextBits: contextBits)
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
    if let stringRef = JSStringRef(bitPattern: record.stringBits) {
      JSStringRelease(stringRef)
    }
    if let contextRef = JSGlobalContextRef(bitPattern: record.contextBits) {
      JSGlobalContextRelease(contextRef)
    }
  }

  /// Unprotect one released persistent binding. Engine work: the caller
  /// schedules this on the VM executor.
  package nonisolated func unprotectPersistentValue(_ refBits: UInt) {
    guard let ref = JSValueRef(bitPattern: refBits) else { return }
    JSValueUnprotect(contextRef, ref)
  }

  /// Isolated deinit (SE-0371): runs on the actor's VM executor, so the
  /// engine-touching teardown never executes on a foreign thread.
  isolated deinit {
    guard let contextRef = engineContext else { return }
    persistentBindings.close()
    defaultScope.drain()
    JSCEngine.installContextDataStorageBox(nil, in: contextRef)
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
    JSGlobalContextRelease(contextRef)
    JSCScopeStacks.pop(for: contextRef)
  }

  // MARK: - Synchronous scopes

  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSCInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = JSCInstantContext(contextRef: contextRef)
    return try body(instantContext)
  }

  public func makeScope() -> JSCScope {
    var scope = JSCScope(contextRef: contextRef)
    scope.open()
    return scope
  }

  // MARK: - Ledger primitives
  //
  // Engine internals (package, never public): every context-level operation
  // below creates or settles an engine reference on the context default scope
  // through these two.

  package func adoptCreatedHandle(_ ref: JSValueRef) -> JSCValue {
    JSCValue(ref: defaultScope.trackCreatedHandle(ref), contextRef: contextRef)
  }

  package func anchorBorrowedHandle(_ ref: JSValueRef) -> JSCValue {
    JSCValue(ref: defaultScope.claimAndTrackHandle(ref), contextRef: contextRef)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> JSCValue {
    guard let ref = JSCEngine.makeStringValueHandle(value, contextRef) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeString(from key: borrowing JSCPropertyStringKey) -> JSCValue {
    guard
      let ref = JSCEngine.makeStringValueHandle(
        fromPropertyStringKey: key.borrowString(in: contextRef),
        in: contextRef
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeNumber(_ value: Double) -> JSCValue {
    guard let ref = JSCEngine.makeNumberValueHandle(value, contextRef) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeBoolean(_ value: Bool) -> JSCValue {
    guard let ref = JSCEngine.makeBooleanValueHandle(value, contextRef) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeNull() -> JSCValue {
    guard let ref = JSCEngine.makeNullValueHandle(contextRef) else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeUndefined() -> JSCValue {
    guard let ref = JSCEngine.makeUndefinedValueHandle(contextRef) else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(ref)
  }

  public func makeObject() -> JSCValue {
    guard let result = JSCEngine.makeObjectResultHandle(contextRef) else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let ref):
      return adoptCreatedHandle(ref)
    case .exception:
      preconditionFailure("JSCContext.makeObject failed")
    }
  }

  public func makeArray() -> JSCValue {
    guard let result = JSCEngine.makeArrayResultHandle(contextRef) else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let ref):
      return adoptCreatedHandle(ref)
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
      let ref = JSCEngine.makeFunctionValueHandle(
        named: name,
        callback: callback,
        in: contextRef
      )
    else {
      preconditionFailure("makeFunctionValueHandle could not create function")
    }
    defaultScope.trackOnDefaultFrame(ref)
    return JSCValue(ref: ref, contextRef: contextRef)
  }

  // MARK: - Persistent bindings

  public func makePersistentHandle(_ value: borrowing JSCValue) -> JSCPersistentHandle {
    precondition(
      value.contextRef == contextRef,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    return JSCPersistentHandle(
      identity: persistentBindings.mint(value.ref),
      registry: persistentBindings,
      context: self
    )
  }

  public func resolve(_ handle: JSCPersistentHandle) -> JSCValue? {
    guard let ref = persistentBindings.borrowLive(handle.identity) else {
      return nil
    }
    defaultScope.frame.track(ref)
    return JSCValue(ref: ref, contextRef: contextRef)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> JSCPropertyStringKey {
    guard let stringRef = JSCEngine.makePropertyStringKeyHandle(value, in: contextRef) else {
      preconditionFailure("makePropertyStringKeyHandle could not create key")
    }
    return JSCPropertyStringKey(
      stringRef: stringRef,
      contextRef: contextRef,
      context: self
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let scriptRef = JSCEngine.makePreparedScriptHandle(source, in: contextRef) else {
      preconditionFailure("makePreparedScriptHandle could not create script")
    }
    return JSCPreparedScript(
      scriptRef: scriptRef,
      contextRef: contextRef,
      context: self
    )
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSCValue {
    guard let ref = JSCEngine.globalObjectValueHandle(contextRef) else {
      preconditionFailure("JSCContext.globalObjectValue could not get global object")
    }
    return JSCValue(ref: ref, contextRef: contextRef)
  }

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> JSCValue {
    guard let global = JSCEngine.globalObjectValueHandle(contextRef) else {
      preconditionFailure("JSCContext.getGlobalProperty could not get global object")
    }
    guard
      let result = JSCEngine.getStaticStringPropertyHandle(key, on: global, in: contextRef)
    else {
      preconditionFailure("JSCContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let ref):
      return adoptCreatedHandle(ref)
    case .exception:
      guard let undefined = JSCEngine.makeUndefinedValueHandle(contextRef) else {
        preconditionFailure("JSCContext could not create an undefined value")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing JSCValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = JSCEngine.globalObjectValueHandle(contextRef) else { return }
    _ = JSCEngine.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.ref,
      in: contextRef,
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = JSCEngine.globalObjectValueHandle(contextRef) else { return }
    _ = JSCEngine.deleteStaticStringPropertyHandle(key, on: global, in: contextRef)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = JSCEngine.globalObjectValueHandle(contextRef) else {
      return false
    }
    return JSCEngine.hasStaticStringPropertyHandle(key, on: global, in: contextRef) ?? false
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing JSCPreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<JSCValue> {
    guard
      let result = JSCEngine.evaluatePreparedScriptResultHandle(
        script.borrowScript(in: contextRef),
        contextRef,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSCContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let ref):
      return .value(adoptCreatedHandle(ref))
    case .exception(let ref):
      return .exception(adoptCreatedHandle(ref))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    JSCEngine.contextDataStorageBox(in: contextRef)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    return JSCEngine.contextDataStorageBox(in: contextRef)?.data(for: key) ?? K.defaultValue
  }

  /// Package-internal data-box seam used by the cross-engine contract tests.
  package nonisolated func contextDataStorageBox() -> JSContextDataStorageBox? {
    JSCEngine.contextDataStorageBox(in: contextRef)
  }

  /// Installs are engine mutations; this stays a hop target for the tests
  /// that swap the box from a foreign thread.
  package func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) async {
    JSCEngine.installContextDataStorageBox(storage, in: contextRef)
  }

  // MARK: - Identity

  /// Force a JavaScriptCore collection. Package-internal so the shared
  /// contract tests can force collection without a public handle API;
  /// `JSGarbageCollect` takes the context ref, not the context group.
  /// JavaScriptCore is thread-safe, so no hop is needed.
  package nonisolated func collectGarbage() {
    JSGarbageCollect(contextRef)
  }

  public nonisolated static func == (lhs: JSCContext, rhs: JSCContext) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
