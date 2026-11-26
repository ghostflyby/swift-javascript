import JavaScriptCore
import SwiftJavaScript

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

  /// The raw JavaScriptCore context every operation of this actor is
  /// addressed through. Package-internal: it must not appear in a public
  /// signature.
  nonisolated(unsafe) let contextRef: JSGlobalContextRef
  /// Cached `Object.keys` wrapper, created before any user script can patch
  /// `Object.keys`. Immutable and only read by engine-side property queries.
  package nonisolated(unsafe) let propertyNamesFunction: JSObjectRef?
  public nonisolated let virtualMachine: JSCVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  private let defaultScope: JSCScopeCore
  private let persistentBindings: JSCPersistentBindings
  private let vmThread: VMThread

  public init() {
    self.init(virtualMachine: JSCVirtualMachine())
  }

  /// Engine access only on the VM thread: `makeContextHandle` creates the
  /// context there, and this initializer's data-box install is posted there
  /// too. `init` is synchronous: a caller on another thread waits for it, a
  /// caller already on the VM thread (inside another context's window) runs
  /// inline.
  public init(virtualMachine: JSCVirtualMachine) {
    guard let contextRef = virtualMachine.makeContextHandle() else {
      preconditionFailure("JSCContext could not create a context from its runtime")
    }
    self.init(virtualMachine: virtualMachine, contextRef: contextRef)
  }

  package init(
    virtualMachine: JSCVirtualMachine,
    contextRef: JSGlobalContextRef
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.contextRef = contextRef
    self.vmThread = virtualMachine.vmThread
    let defaultScope = JSCScopeCore(contextRef: contextRef, rootsArenaValues: true)
    self.defaultScope = defaultScope
    let persistentBindings = JSCPersistentBindings(
      contextRef: contextRef,
      vmThread: virtualMachine.vmThread
    )
    self.persistentBindings = persistentBindings
    let contextBits = UInt(bitPattern: contextRef)
    let propertyNamesBits = virtualMachine.vmThread.runAndWait { () -> UInt? in
      guard let contextRef = JSGlobalContextRef(bitPattern: contextBits) else {
        return nil
      }
      guard let function = JSCEngine.makePropertyNamesFunction(in: contextRef) else {
        return nil
      }
      return UInt(bitPattern: function)
    }
    self.propertyNamesFunction = propertyNamesBits.flatMap { JSObjectRef(bitPattern: $0) }
    JSCScopeStacks.push(defaultScope)

    // The context data box exists from the end of init: synchronous scope
    // witnesses reach the binding table through it, and the box remembers
    // this actor as its unretained owner (used by raw callback contexts).
    let box = JSContextDataStorageBox()
    virtualMachine.vmThread.runAndWait {
      guard let contextRef = JSGlobalContextRef(bitPattern: contextBits) else {
        return
      }
      JSCEngine.installContextDataStorageBox(box, in: contextRef)
      box.bindContextOwner(self)
      box.setData(persistentBindings, for: JSCPersistentBindingsKey.self)
    }
    JSCScopeStacks.bind(virtualMachine.vmThread, for: contextRef)
  }

  /// Isolated deinit (SE-0371): runs on the actor's dedicated VM thread, so
  /// the engine-touching teardown never executes on a foreign thread.
  isolated deinit {
    persistentBindings.close()
    defaultScope.drain()
    let contextBits = UInt(bitPattern: contextRef)
    let vmThread = self.vmThread
    vmThread.runAndWait {
      guard let contextRef = JSGlobalContextRef(bitPattern: contextBits) else {
        return
      }
      JSCEngine.installContextDataStorageBox(nil, in: contextRef)
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
      registry: persistentBindings
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
      vmThread: vmThread
    )
  }

  public func prepareScript(_ source: String) -> JSCPreparedScript {
    guard let scriptRef = JSCEngine.makePreparedScriptHandle(source, in: contextRef) else {
      preconditionFailure("makePreparedScriptHandle could not create script")
    }
    return JSCPreparedScript(
      scriptRef: scriptRef,
      contextRef: contextRef,
      vmThread: vmThread
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
    JSCEngine.contextDataStorageBox(in: contextRef)?.data(for: key) ?? K.defaultValue
  }

  /// Package-internal data-box seam used by the cross-engine contract tests.
  package nonisolated func contextDataStorageBox() -> JSContextDataStorageBox? {
    JSCEngine.contextDataStorageBox(in: contextRef)
  }

  package nonisolated func installContextDataStorageBox(_ storage: JSContextDataStorageBox?) {
    let contextBits = UInt(bitPattern: contextRef)
    if let vmThread = JSCScopeStacks.vmThread(for: contextRef) {
      vmThread.perform {
        guard let contextRef = JSGlobalContextRef(bitPattern: contextBits) else {
          return
        }
        JSCEngine.installContextDataStorageBox(storage, in: contextRef)
      }
    } else {
      JSCEngine.installContextDataStorageBox(storage, in: contextRef)
    }
  }

  // MARK: - Identity

  /// Force a JavaScriptCore collection. Engine work: callers run on the VM
  /// thread (a callback window or the actor's isolation). Package-internal so
  /// the shared contract tests can force collection without a public handle
  /// API; `JSGarbageCollect` takes the context ref, not the context group.
  package nonisolated func collectGarbage() {
    JSGarbageCollect(contextRef)
  }

  public nonisolated static func == (lhs: JSCContext, rhs: JSCContext) -> Bool {
    lhs.contextRef == rhs.contextRef
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(UInt(bitPattern: contextRef))
  }
}
