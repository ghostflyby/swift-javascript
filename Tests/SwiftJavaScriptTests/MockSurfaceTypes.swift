import SwiftJavaScript
import Testing

// MARK: - Mock surface types
//
// Independent implementations of `MockSurfaceContext`'s types, anchored on
// that context the way the production engines are. The names avoid the
// `MockContext`, `MockValue`, and `MockClass` value models.

public struct MockSurfaceValue: SwiftJavaScript.JSValue, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias ValueHandle = MockValueHandle
  public typealias InstantContext = MockSurfaceInstantContext

  let handle: MockValueHandle
  public let contextHandle: MockContextHandle

  init(handle: MockValueHandle, contextHandle: MockContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  public borrowing func borrowHandle() -> MockValueHandle {
    handle
  }

  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("MockSurfaceValue.type() could not query value type")
    }
    return valueType
  }
}

public struct MockSurfaceCallbackValue: SwiftJavaScript.JSCallbackValue, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias ValueHandle = MockValueHandle

  let handle: MockValueHandle
  public let contextHandle: MockContextHandle

  init(handle: MockValueHandle, contextHandle: MockContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  public borrowing func borrowHandle() -> MockValueHandle {
    handle
  }

  @available(*, noasync)
  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("MockSurfaceCallbackValue.type() could not query value type")
    }
    return valueType
  }
}

public struct MockSurfaceCallbackReturn: SwiftJavaScript.JSCallbackReturn, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ValueHandle = MockValueHandle

  let handle: MockValueHandle
  public let isException: Bool

  init(handle: MockValueHandle, isException: Bool = false) {
    self.handle = handle
    self.isException = isException
  }

  public borrowing func borrowHandle() -> MockValueHandle {
    handle
  }
}

public struct MockSurfaceArguments: SwiftJavaScript.JSArguments, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias Value = MockSurfaceValue
  public typealias InstantContext = MockSurfaceInstantContext

  public let count: Int
  let borrowedValueHandleAt: (Int, MockContextHandle) -> MockValueHandle?

  init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int, MockContextHandle) -> MockValueHandle?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
  }

  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing MockSurfaceInstantContext,
    _ body: (borrowing MockSurfaceValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index, context.driverContextHandle) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(
      MockSurfaceValue(handle: handle, contextHandle: context.driverContextHandle))
  }
}

public struct MockSurfaceCallbackArguments: SwiftJavaScript.JSCallbackArguments, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias Value = MockSurfaceCallbackValue
  public typealias InstantContext = MockSurfaceInstantContext

  public let count: Int
  let borrowedValueHandleAt: (Int) -> MockValueHandle?

  init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int) -> MockValueHandle?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
  }

  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing MockSurfaceInstantContext,
    _ body: (borrowing MockSurfaceCallbackValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(
      MockSurfaceCallbackValue(handle: handle, contextHandle: context.driverContextHandle))
  }

  public func withThrowingValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing MockSurfaceInstantContext,
    _ body: (borrowing MockSurfaceCallbackValue) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return try body(
      MockSurfaceCallbackValue(handle: handle, contextHandle: context.driverContextHandle))
  }
}

public struct MockSurfaceInstantContext: SwiftJavaScript.JSInstantContext, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias Value = MockSurfaceValue
  public typealias CallbackValue = MockSurfaceCallbackValue
  public typealias CallbackReturn = MockSurfaceCallbackReturn
  public typealias CallbackArguments = MockSurfaceCallbackArguments
  public typealias Arguments = MockSurfaceArguments
  public typealias PropertyStringKey = MockSurfacePropertyStringKey
  public typealias PreparedScript = MockSurfacePreparedScript
  public typealias PersistentHandle = MockSurfacePersistentHandle

  private var core: ScopeCore<MockContextHandle, JSImplicitStackRoots>

  public var driverContextHandle: MockContextHandle { core.driverContextHandle }

  init(handle: MockContextHandle) {
    self.core = ScopeCore(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  // MARK: - Ledger primitives

  public func adoptCreatedHandle(
    _ handle: consuming MockOwnedValueHandle
  ) -> MockSurfaceValue {
    MockSurfaceValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func adoptCallbackHandle(
    _ handle: consuming MockOwnedValueHandle
  ) -> MockSurfaceCallbackValue {
    MockSurfaceCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: MockValueHandle) -> MockSurfaceValue {
    MockSurfaceValue(
      handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<MockContextHandle>.pop(for: core.driverContextHandle)
  }
}

public struct MockSurfaceScope: SwiftJavaScript.JSScope, ~Copyable, ~Sendable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias Value = MockSurfaceValue
  public typealias CallbackValue = MockSurfaceCallbackValue
  public typealias PropertyStringKey = MockSurfacePropertyStringKey
  public typealias InstantContext = MockSurfaceInstantContext
  public typealias PreparedScript = MockSurfacePreparedScript
  public typealias PersistentHandle = MockSurfacePersistentHandle

  private var core: ScopeCore<MockContextHandle, JSImplicitStackRoots>
  private var isOpen = false

  public var driverContextHandle: MockContextHandle { core.driverContextHandle }

  init(handle: MockContextHandle) {
    self.core = ScopeCore(handle: handle)
  }

  mutating func open() {
    guard !isOpen else { return }
    ScopeStackRegistry.push(core, for: core.driverContextHandle)
    isOpen = true
  }

  // MARK: - Ledger primitives

  public func adoptCreatedHandle(
    _ handle: consuming MockOwnedValueHandle
  ) -> MockSurfaceValue {
    MockSurfaceValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func adoptCallbackHandle(
    _ handle: consuming MockOwnedValueHandle
  ) -> MockSurfaceCallbackValue {
    MockSurfaceCallbackValue(
      handle: core.trackCreatedHandle(handle), contextHandle: core.driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: MockValueHandle) -> MockSurfaceValue {
    MockSurfaceValue(
      handle: core.claimAndTrackHandle(handle), contextHandle: core.driverContextHandle)
  }

  deinit {
    core.drain()
    if isOpen { ScopeStackRegistry<MockContextHandle>.pop(for: core.driverContextHandle) }
  }
}

extension MockSurfaceInstantContext: JSScopeWitness {
  package var scopeFrame: ScopeFrame<MockContextHandle> { core.frame }

  package func makeValue(handle: MockValueHandle) -> MockSurfaceValue {
    MockSurfaceValue(handle: handle, contextHandle: core.driverContextHandle)
  }
}

extension MockSurfaceScope: JSScopeWitness {
  package var scopeFrame: ScopeFrame<MockContextHandle> { core.frame }

  package func makeValue(handle: MockValueHandle) -> MockSurfaceValue {
    MockSurfaceValue(handle: handle, contextHandle: core.driverContextHandle)
  }
}

// MARK: - Scope operations (S7)
//
// The value factories, global reads and script evaluation are the scope
// protocol defaults, which ride on the ledger primitives above and the same
// handle-level `ScopeCore` the production engines use; the ledger assertions
// therefore exercise the shared code. What remains here is the mock's part:
// the callback exits, the wrappers around handles, and function creation.

extension MockSurfaceInstantContext {
  public func persist(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfaceValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return MockSurfaceValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  public func `return`(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfaceCallbackReturn {
    MockSurfaceCallbackReturn(handle: value.borrowHandle())
  }

  public func `return`(_ value: borrowing MockSurfaceValue) -> MockSurfaceCallbackReturn {
    MockSurfaceCallbackReturn(handle: value.borrowHandle())
  }

  public func `throw`(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfaceCallbackReturn {
    MockSurfaceCallbackReturn(handle: value.borrowHandle(), isException: true)
  }

  public func `throw`(_ value: borrowing MockSurfaceValue) -> MockSurfaceCallbackReturn {
    MockSurfaceCallbackReturn(handle: value.borrowHandle(), isException: true)
  }

  public func returnUndefined() -> MockSurfaceCallbackReturn {
    MockSurfaceCallbackReturn(handle: makeUndefined().borrowHandle())
  }

  public func throwUndefined() -> MockSurfaceCallbackReturn {
    MockSurfaceCallbackReturn(handle: makeUndefined().borrowHandle(), isException: true)
  }

  public func globalObjectValue() -> MockSurfaceValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure(
        "MockSurfaceInstantContext.globalObjectValue could not get global object")
    }
    return MockSurfaceValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<MockSurfaceInstantContext>
  ) -> MockSurfaceValue {
    guard
      let handle = core.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    let borrowed = handle.borrowed()
    core.trackOnDefaultFrame(handle)
    return MockSurfaceValue(handle: borrowed, contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfacePersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing MockSurfaceValue
  ) -> MockSurfacePersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func resolve(_ handle: MockSurfacePersistentHandle) -> MockSurfaceValue? {
    resolvePersistentHandle(handle.identity, in: self)
  }

  public func makePropertyStringKey(_ value: String) -> MockSurfacePropertyStringKey {
    guard let handle = core.driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return MockSurfacePropertyStringKey(handle: handle)
  }

  public func prepareScript(_ source: String) -> MockSurfacePreparedScript {
    guard let handle = core.driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return MockSurfacePreparedScript(handle: handle)
  }
}

extension MockSurfaceScope {
  public func persist(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfaceValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return MockSurfaceValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  public func globalObjectValue() -> MockSurfaceValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("MockSurfaceScope.globalObjectValue could not get global object")
    }
    return MockSurfaceValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<MockSurfaceInstantContext>
  ) -> MockSurfaceValue {
    guard
      let handle = core.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    let borrowed = handle.borrowed()
    core.trackOnDefaultFrame(handle)
    return MockSurfaceValue(handle: borrowed, contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfacePersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing MockSurfaceValue
  ) -> MockSurfacePersistentHandle {
    mintPersistentHandle(value.borrowHandle(), of: value.contextHandle, on: core)
  }

  @available(*, noasync)
  public func resolve(_ handle: MockSurfacePersistentHandle) -> MockSurfaceValue? {
    resolvePersistentHandle(handle.identity, in: self)
  }

  public func makePropertyStringKey(_ value: String) -> MockSurfacePropertyStringKey {
    guard let handle = core.driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return MockSurfacePropertyStringKey(handle: handle)
  }

  public func prepareScript(_ source: String) -> MockSurfacePreparedScript {
    guard let handle = core.driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return MockSurfacePreparedScript(handle: handle)
  }
}

/// Mint a persistent binding through the context's registry, which the mock
/// context publishes into its context data box.
@available(*, noasync)
private func mintPersistentHandle(
  _ handle: MockValueHandle,
  of contextHandle: MockContextHandle,
  on core: borrowing ScopeCore<MockContextHandle, JSImplicitStackRoots>
) -> MockSurfacePersistentHandle {
  precondition(
    contextHandle == core.driverContextHandle,
    "JSPersistentHandle can only be minted for values of its own context"
  )
  guard
    let registry = JSPersistentHandleRegistry<MockContextHandle>.registry(
      for: core.driverContextHandle)
  else {
    preconditionFailure(
      "JSPersistentHandle minting requires a hosted JSContext (no registry installed)"
    )
  }
  return MockSurfacePersistentHandle(
    identity: registry.mintIdentity(handle), registry: registry)
}

public actor MockSurfaceContext {
  public typealias ContextHandle = MockContextHandle
  public typealias ValueHandle = MockValueHandle
  public typealias OwnedValueHandle = MockOwnedValueHandle
  public typealias VirtualMachine = MockSurfaceVirtualMachine
  public typealias InstantContext = MockSurfaceInstantContext
  public typealias Scope = MockSurfaceScope
  public typealias Value = MockSurfaceValue
  public typealias CallbackValue = MockSurfaceCallbackValue
  public typealias CallbackReturn = MockSurfaceCallbackReturn
  public typealias CallbackArguments = MockSurfaceCallbackArguments
  public typealias PersistentHandle = MockSurfacePersistentHandle
  public typealias Arguments = MockSurfaceArguments
  public typealias ArrayBuffer = MockSurfaceArrayBuffer
  public typealias TypedArray = MockSurfaceTypedArray
  public typealias ClassHandle = MockClassHandle
  public typealias Class = MockSurfaceClass
  public typealias PropertyStringKey = MockSurfacePropertyStringKey
  public typealias PreparedScript = MockSurfacePreparedScript

  public nonisolated let driverContextHandle: MockContextHandle
  public nonisolated let virtualMachine: MockSurfaceVirtualMachine
  public nonisolated let unownedExecutor: UnownedSerialExecutor

  /// Same shape as the production contexts: the context owns an
  /// explicit-rooted default scope so context-level factories can park their
  /// creation references there, and a persistent registry published into the
  /// context data box for synchronous scope witnesses.
  private let defaultScope: ScopeCore<MockContextHandle, JSExplicitRoots>
  private let persistentRegistry: JSPersistentHandleRegistry<MockContextHandle>

  public init() {
    self.init(virtualMachine: MockSurfaceVirtualMachine())
  }

  public init(virtualMachine: MockSurfaceVirtualMachine) {
    guard let handle = virtualMachine.makeContextHandle() else {
      preconditionFailure("MockSurfaceContext could not create a context handle")
    }
    self.init(virtualMachine: virtualMachine, driverContextHandle: handle)
  }

  init(driverContextHandle: MockContextHandle) {
    self.init(
      virtualMachine: MockSurfaceVirtualMachine(
        driverRuntimeHandle: MockRuntimeHandle(
          rawRuntime: MockRuntime(id: driverContextHandle.rawContext.runtimeID)
        )
      ),
      driverContextHandle: driverContextHandle
    )
  }

  private init(
    virtualMachine: MockSurfaceVirtualMachine,
    driverContextHandle handle: MockContextHandle
  ) {
    self.virtualMachine = virtualMachine
    self.driverContextHandle = handle
    self.unownedExecutor = virtualMachine.unownedExecutor
    let defaultScope = ScopeCore<MockContextHandle, JSExplicitRoots>(handle: handle)
    self.defaultScope = defaultScope
    ScopeStackRegistry.push(defaultScope, for: handle)
    // Install the data box before binding the VM thread: the install is part
    // of construction and must be visible to the first synchronous query on
    // any thread. Later swaps are routed to the VM thread.
    let box = JSContextDataStorageBox()
    handle.installContextDataStorageBox(box)
    let registry = JSPersistentHandleRegistry<MockContextHandle>(
      contextHandle: handle,
      scheduler: MockPersistentCleanupScheduler()
    )
    self.persistentRegistry = registry
    box.setData(registry, for: JSPersistentHandleRegistryKey<MockContextHandle>.self)
    ScopeStackRegistry<MockContextHandle>.bind(virtualMachine.vmThread, for: handle)
  }

  deinit {
    persistentRegistry.close()
    defaultScope.drain()
    ScopeStackRegistry<MockContextHandle>.pop(for: driverContextHandle)
  }

  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing MockSurfaceInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = MockSurfaceInstantContext(handle: driverContextHandle)
    return try body(instantContext)
  }

  public func makeScope() -> MockSurfaceScope {
    var scope = MockSurfaceScope(handle: driverContextHandle)
    scope.open()
    return scope
  }

  // MARK: - Ledger primitives

  public func adoptCreatedHandle(
    _ handle: consuming MockOwnedValueHandle
  ) -> MockSurfaceValue {
    MockSurfaceValue(
      handle: defaultScope.trackCreatedHandle(handle), contextHandle: driverContextHandle)
  }

  public func anchorBorrowedHandle(_ handle: MockValueHandle) -> MockSurfaceValue {
    MockSurfaceValue(
      handle: defaultScope.claimAndTrackHandle(handle), contextHandle: driverContextHandle)
  }

  // MARK: - Persistent bindings

  public func makePersistentHandle(
    _ value: borrowing MockSurfaceValue
  ) -> MockSurfacePersistentHandle {
    precondition(
      value.contextHandle == driverContextHandle,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    return MockSurfacePersistentHandle(
      identity: persistentRegistry.mintIdentity(value.borrowHandle()),
      registry: persistentRegistry
    )
  }

  public func resolve(_ handle: MockSurfacePersistentHandle) -> MockSurfaceValue? {
    guard let borrowed = persistentRegistry.borrowLive(handle.identity) else {
      return nil
    }
    return MockSurfaceValue(
      handle: defaultScope.claimAndTrackHandle(borrowed), contextHandle: driverContextHandle)
  }

  // MARK: - Self-owning inputs

  public func makePropertyStringKey(_ value: String) -> MockSurfacePropertyStringKey {
    guard let handle = driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("makePropertyStringKeyHandle could not create handle")
    }
    return MockSurfacePropertyStringKey(handle: handle)
  }

  public func prepareScript(_ source: String) -> MockSurfacePreparedScript {
    guard let handle = driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("makePreparedScriptHandle could not create handle")
    }
    return MockSurfacePreparedScript(handle: handle)
  }

  // MARK: - Global object

  public func globalObjectValue() -> MockSurfaceValue {
    guard let handle = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("MockSurfaceContext.globalObjectValue could not get global object")
    }
    return MockSurfaceValue(handle: handle, contextHandle: driverContextHandle)
  }

  // MARK: - Identity

  public nonisolated static func == (lhs: MockSurfaceContext, rhs: MockSurfaceContext) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}

// The conformance is stated in an extension rather than on the declaration on
// purpose. Tests in files sorted before this one construct the actor, and
// SwiftPM's module-emit pass type-checks those bodies before it reaches this
// file. With an inline conformance, that order makes the compiler reject
// `init(virtualMachine:)` — the witness of an `Actor`-refining protocol's
// initializer requirement — as "'nonisolated' on an actor's synchronous
// initializer is invalid", although the same declaration is accepted as soon
// as the actor has been seen first. Stating the conformance after the fact
// keeps both orders compiling. The production contexts are safe either way:
// nothing in their modules reaches their initializers before their files.
extension MockSurfaceContext: SwiftJavaScript.JSContext {}

extension MockSurfaceContext {
  /// Legacy-shaped helper used by the core tests: run `body` in this actor's
  /// isolation with the global object view. `self` is passed as an `isolated`
  /// parameter so the closure may call actor-isolated operations.
  func withIsolatedGlobalObject<R: ~Copyable>(
    _ body: @Sendable (isolated MockSurfaceContext, borrowing MockSurfaceValue) -> R
  ) -> R {
    body(self, globalObjectValue())
  }

  /// Adopt a borrowed handle on the context default scope and hand the
  /// produced view to an isolated closure.
  func withAdoptedValue<R: ~Copyable>(
    _ handle: MockValueHandle,
    _ body: @Sendable (isolated MockSurfaceContext, borrowing MockSurfaceValue) -> R
  ) -> R {
    let value = adoptCreatedHandle(MockOwnedValueHandle.adopting(handle))
    return body(self, value)
  }
}

public final class MockSurfaceVirtualMachine: SwiftJavaScript.JSVirtualMachine,
  @unchecked Sendable
{
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias RuntimeHandle = MockRuntimeHandle

  public let driverRuntimeHandle: MockRuntimeHandle
  private let thread: VMThread

  public convenience init() {
    self.init(driverRuntimeHandle: MockEngine.makeRuntimeHandle(), thread: VMThread())
  }

  convenience init(driverRuntimeHandle: MockRuntimeHandle) {
    self.init(driverRuntimeHandle: driverRuntimeHandle, thread: VMThread())
  }

  private init(driverRuntimeHandle: MockRuntimeHandle, thread: VMThread) {
    self.driverRuntimeHandle = driverRuntimeHandle
    self.thread = thread
  }

  package var vmThread: VMThread { thread }

  public var unownedExecutor: UnownedSerialExecutor {
    thread.unownedExecutor
  }

  public func makeContextHandle() -> MockContextHandle? {
    MockEngine.makeBorrowedContextHandleFromRuntime(in: driverRuntimeHandle)
  }

  public static func == (lhs: MockSurfaceVirtualMachine, rhs: MockSurfaceVirtualMachine) -> Bool {
    lhs.driverRuntimeHandle == rhs.driverRuntimeHandle
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(driverRuntimeHandle)
  }
}

public final class MockSurfacePersistentHandle: SwiftJavaScript.JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity
  private let registryReference: PersistentRegistryReference<MockContextHandle>

  init(
    identity: JSPersistentHandleIdentity,
    registry: JSPersistentHandleRegistry<MockContextHandle>
  ) {
    self.identity = identity
    self.registryReference = PersistentRegistryReference(registry)
  }

  @discardableResult
  public func invalidate() -> Bool {
    registryReference.value?.release(identity) ?? false
  }

  deinit {
    _ = registryReference.value?.release(identity)
  }

  public static func == (
    lhs: MockSurfacePersistentHandle,
    rhs: MockSurfacePersistentHandle
  ) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}

/// Inline cleanup scheduler for the mock registry. There is no VM thread, so
/// settlement runs at the scheduling call site and the claim/root/release
/// logs stay observable.
private final class MockPersistentCleanupScheduler: JSPersistentCleanupScheduler,
  @unchecked Sendable
{
  func schedulePersistentCleanup(_ body: @escaping @Sendable () -> Void) {
    body()
  }
}

public struct MockSurfacePropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable,
  ~Copyable
{
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias Handle = MockStringHandle

  let handle: MockStringHandle

  init(handle: MockStringHandle) {
    self.handle = handle
  }

  public borrowing func borrowHandle(in contextHandle: MockContextHandle) -> MockStringHandle {
    precondition(
      contextHandle.isPropertyStringKeyHandleCompatibleWithContext(handle),
      "MockSurfacePropertyStringKey can only be used with the context that created it"
    )
    return handle
  }
}

public struct MockSurfacePreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias Handle = MockStringHandle

  let handle: MockStringHandle

  init(handle: MockStringHandle) {
    self.handle = handle
  }

  public borrowing func borrowHandle(in contextHandle: MockContextHandle) -> MockStringHandle {
    precondition(
      contextHandle.isPreparedScriptHandleCompatibleWithContext(handle),
      "MockSurfacePreparedScript can only be used with the context that compiled it"
    )
    return handle
  }
}

// MARK: - Buffers (S10)
//
// The mock models the same construction seam the engines use: the shared core
// byte helpers allocate/copy, `MockContextHandle` reports acceptance or
// rejection, and the calling window adopts the creation reference once.

public struct MockSurfaceArrayBuffer: SwiftJavaScript.JSArrayBuffer, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias Value = MockSurfaceValue
  public typealias InstantContext = MockSurfaceInstantContext

  let value: MockSurfaceValue

  init(value: consuming MockSurfaceValue) {
    self.value = value
  }

  public var contextHandle: MockContextHandle { value.contextHandle }

  public borrowing func borrowHandle() -> MockValueHandle {
    value.borrowHandle()
  }

  public borrowing func withValue<R: ~Copyable>(
    _ body: (borrowing MockSurfaceValue) -> R
  ) -> R {
    body(value)
  }

  public init(byteLength: Int, in context: borrowing MockSurfaceInstantContext) {
    precondition(byteLength >= 0, "ArrayBuffer byteLength must be non-negative")
    guard
      let value = adoptArrayBufferBytesNoCopy(
        allocateZeroedArrayBufferBytes(byteLength: byteLength),
        byteLength: byteLength,
        in: context
      )
    else {
      preconditionFailure("MockEngine rejected the ArrayBuffer")
    }
    self.init(value: value)
  }

  public init(copying bytes: [UInt8], in context: borrowing MockSurfaceInstantContext) {
    guard
      let value = adoptArrayBufferBytesNoCopy(
        allocateArrayBufferBytes(copying: bytes),
        byteLength: bytes.count,
        in: context
      )
    else {
      preconditionFailure("MockEngine rejected the ArrayBuffer")
    }
    self.init(value: value)
  }

  public init(
    copying bytes: UnsafeRawBufferPointer,
    in context: borrowing MockSurfaceInstantContext
  ) {
    guard
      let value = adoptArrayBufferBytesNoCopy(
        allocateArrayBufferBytes(copying: bytes),
        byteLength: bytes.count,
        in: context
      )
    else {
      preconditionFailure("MockEngine rejected the ArrayBuffer")
    }
    self.init(value: value)
  }

  public init?(
    value: borrowing MockSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) {
    guard context.driverContextHandle.isArrayBufferHandle(value.borrowHandle()) else {
      return nil
    }
    self.init(value: context.anchorBorrowedHandle(value.borrowHandle()))
  }
}

public struct MockSurfaceTypedArray: SwiftJavaScript.JSTypedArray, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias ContextHandle = MockContextHandle
  public typealias Value = MockSurfaceValue
  public typealias InstantContext = MockSurfaceInstantContext
  public typealias Buffer = MockSurfaceArrayBuffer

  let value: MockSurfaceValue

  init(value: consuming MockSurfaceValue) {
    self.value = value
  }

  public var contextHandle: MockContextHandle { value.contextHandle }

  public borrowing func borrowHandle() -> MockValueHandle {
    value.borrowHandle()
  }

  public borrowing func withValue<R: ~Copyable>(
    _ body: (borrowing MockSurfaceValue) -> R
  ) -> R {
    body(value)
  }

  public init(
    kind: JSTypedArrayKind,
    length: Int,
    in context: borrowing MockSurfaceInstantContext
  ) {
    precondition(length >= 0, "TypedArray length must be non-negative")
    guard
      let handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        length: length
      )
    else {
      preconditionFailure("MockEngine does not model TypedArrays")
    }
    self.init(
      value: context.adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
  }

  public init(
    kind: JSTypedArrayKind,
    buffer: borrowing MockSurfaceArrayBuffer,
    byteOffset: Int,
    length: Int?,
    in context: borrowing MockSurfaceInstantContext
  ) {
    precondition(byteOffset >= 0, "TypedArray byteOffset must be non-negative")
    if let length {
      precondition(length >= 0, "TypedArray length must be non-negative")
    }

    let bufferHandle = buffer.borrowHandle()
    let handle: MockValueHandle?
    if let length {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: length
      )
    } else if byteOffset == 0 {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        arrayBuffer: bufferHandle
      )
    } else {
      handle = context.driverContextHandle.makeTypedArrayHandle(
        kind: kind,
        arrayBuffer: bufferHandle,
        byteOffset: byteOffset,
        length: buffer.remainingElementCount(from: byteOffset, kind: kind)
      )
    }

    guard let handle else {
      preconditionFailure("MockEngine does not model TypedArrays")
    }
    self.init(
      value: context.adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
  }

  public init?(
    value: borrowing MockSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) {
    guard
      context.driverContextHandle.typedArrayKindForHandle(value.borrowHandle()) != nil
    else {
      return nil
    }
    self.init(value: context.anchorBorrowedHandle(value.borrowHandle()))
  }

  public var buffer: MockSurfaceArrayBuffer {
    guard
      let bufferHandle = contextHandle.typedArrayBufferForHandle(value.borrowHandle()),
      let target = ScopeStackRegistry<MockContextHandle>.defaultFrame(for: contextHandle)
    else {
      preconditionFailure("MockEngine does not model TypedArray buffers")
    }
    target.track(MockOwnedValueHandle.adopting(bufferHandle))
    return MockSurfaceArrayBuffer(
      value: MockSurfaceValue(handle: bufferHandle, contextHandle: contextHandle))
  }
}

/// The mock context's class. `MockClass` is the raw value model, so the
/// class gets its own name and wraps the existing class handle.
public final class MockSurfaceClass: SwiftJavaScript.JSClass, @unchecked Sendable {
  public typealias Context = MockSurfaceContext
  public typealias ClassHandle = MockClassHandle

  let rawHandle: MockClassHandle

  init(classHandle: MockClassHandle) {
    self.rawHandle = classHandle
  }

  public func classHandle() -> MockClassHandle {
    rawHandle
  }
}

extension MockSurfaceClass: Equatable {
  public static func == (lhs: MockSurfaceClass, rhs: MockSurfaceClass) -> Bool {
    lhs.rawHandle == rhs.rawHandle
  }
}

extension MockSurfaceClass: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawHandle)
  }
}

// MARK: - Class bridge
//
// `MockEngine` as the engine-side class bridge, so the shared class definition
// and descriptor templates can be written against the mock. The mock never
// creates a host object: both storage hooks report "unsupported" (`nil`),
// which the shared conversion code maps to a `JSValueConversionError`.

extension MockEngine: JSEngineRuntimeDriver, JSEngineClassBridgeDriver {
  public typealias Context = MockSurfaceContext
  public typealias Value = MockSurfaceValue
  public typealias InstantContext = MockSurfaceInstantContext
  public typealias Arguments = MockSurfaceArguments
  public typealias Class = MockSurfaceClass
  public typealias ClassPropertyNameAccumulator = Never

  public static func makeClass(
    definition: JSEngineClassDefinition<
      MockEngine, JSClassParentDescriptor<MockEngine, Never>, Never
    >,
    in runtime: MockRuntimeHandle
  ) -> MockSurfaceClass {
    _ = runtime
    return MockSurfaceClass(
      classHandle: MockClassHandle(rawClass: MockClass(id: definition.className ?? "")))
  }

  public static func runtimeHandle(for context: MockContextHandle) -> MockRuntimeHandle? {
    MockRuntimeHandle(rawRuntime: MockRuntime(id: context.rawContext.runtimeID))
  }

  public static func makeClassObjectResultHandle(
    of jsClass: MockSurfaceClass,
    privateData: UnsafeMutableRawPointer,
    in context: MockContextHandle
  ) -> JSResult<MockValueHandle>? {
    nil
  }

  public static func classObjectPrivateData(
    from value: MockValueHandle,
    in context: MockContextHandle
  ) -> JSResult<UnsafeMutableRawPointer?>? {
    nil
  }
}

// MARK: - Compile-time context checks

/// `MockSurfaceContext` names every type of the mock; this sink compiles only
/// while the mock's types are exactly the ones its context associates (see
/// `SurfaceConformanceTests` in the cross-engine target for the same shape).
private func checkContextAssociations<C: SwiftJavaScript.JSContext>(
  _: C.Type,
  contextHandle: C.ContextHandle.Type,
  valueHandle: C.ValueHandle.Type,
  ownedValueHandle: C.OwnedValueHandle.Type,
  value: C.Value.Type,
  callbackValue: C.CallbackValue.Type,
  callbackReturn: C.CallbackReturn.Type,
  arguments: C.Arguments.Type,
  callbackArguments: C.CallbackArguments.Type,
  instantContext: C.InstantContext.Type,
  scope: C.Scope.Type,
  virtualMachine: C.VirtualMachine.Type,
  persistentHandle: C.PersistentHandle.Type,
  propertyStringKey: C.PropertyStringKey.Type,
  preparedScript: C.PreparedScript.Type,
  arrayBuffer: C.ArrayBuffer.Type,
  typedArray: C.TypedArray.Type,
  classHandle: C.ClassHandle.Type,
  jsClass: C.Class.Type
) {}

@Test func mockSurfaceSatisfiesContextEquations() {
  checkContextAssociations(
    MockSurfaceContext.self,
    contextHandle: MockContextHandle.self,
    valueHandle: MockValueHandle.self,
    ownedValueHandle: MockOwnedValueHandle.self,
    value: MockSurfaceValue.self,
    callbackValue: MockSurfaceCallbackValue.self,
    callbackReturn: MockSurfaceCallbackReturn.self,
    arguments: MockSurfaceArguments.self,
    callbackArguments: MockSurfaceCallbackArguments.self,
    instantContext: MockSurfaceInstantContext.self,
    scope: MockSurfaceScope.self,
    virtualMachine: MockSurfaceVirtualMachine.self,
    persistentHandle: MockSurfacePersistentHandle.self,
    propertyStringKey: MockSurfacePropertyStringKey.self,
    preparedScript: MockSurfacePreparedScript.self,
    arrayBuffer: MockSurfaceArrayBuffer.self,
    typedArray: MockSurfaceTypedArray.self,
    classHandle: MockClassHandle.self,
    jsClass: MockSurfaceClass.self
  )
}
