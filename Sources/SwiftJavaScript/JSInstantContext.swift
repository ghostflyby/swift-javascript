import Synchronization

// MARK: - Scope stack infrastructure

/// LIFO stack of scope frames for a single context. Frames are the scope
/// cores pushed by scope entry (`JSInstantContext.init`, `JSScope.open`)
/// and popped on scope exit; a frame's arena is shared with the scope
/// object that pushed it.
internal final class ScopeStack<E: JSEngine>: @unchecked Sendable {
  private var frames: [ScopeCore<E>] = []

  func push(_ core: ScopeCore<E>) { frames.append(core) }
  @discardableResult
  func pop() -> ScopeCore<E>? { frames.popLast() }
  var top: ScopeCore<E>? { frames.last }
  var isEmpty: Bool { frames.isEmpty }
}

/// Non-generic mutex-backed storage for the per-engine registry below
/// (static stored properties are not supported in generic types).
private enum ScopeStackStorage {
  final class State: @unchecked Sendable {
    var stacks: [AnyHashable: Any] = [:]
  }

  static let state = Mutex(State())
}

/// Per-engine registry of per-context scope stacks, keyed by context handle.
/// Scope addressing lives on the context, not the thread: execution is
/// serialized by each VM's dedicated executor, so a context's stack is only
/// mutated by its JS thread in practice; the mutex guards the registry
/// structure itself against cross-thread structural access. There is
/// deliberately no process-wide "current context": the top of a context's
/// own stack is the only notion of current. Context handles of different
/// engines are distinct `AnyHashable` keys, so the shared storage cannot
/// mix stacks across engines.
internal enum ScopeStackRegistry<E: JSEngine> {

  static func push(_ core: ScopeCore<E>, for context: E.ContextHandle) {
    ScopeStackStorage.state.withLock {
      let key = AnyHashable(context)
      let stack = ($0.stacks[key] as? ScopeStack<E>) ?? ScopeStack()
      stack.push(core)
      $0.stacks[key] = stack
    }
  }

  @discardableResult
  static func pop(for context: E.ContextHandle) -> ScopeCore<E>? {
    ScopeStackStorage.state.withLock {
      let key = AnyHashable(context)
      guard let stack = $0.stacks[key] as? ScopeStack<E> else { return nil }
      let popped = stack.pop()
      if stack.isEmpty {
        $0.stacks.removeValue(forKey: key)
      }
      return popped
    }
  }

  /// The topmost open scope of a context, if any. Engine results from value
  /// operations are tracked on it.
  static func top(of context: E.ContextHandle) -> ScopeCore<E>? {
    ScopeStackStorage.state.withLock {
      $0.stacks[AnyHashable(context)] as? ScopeStack<E>
    }?.top
  }
}

// MARK: - JSCallbackReturn

public struct JSCallbackReturn<E: JSEngine>: ~Copyable {
  package let handle: JSValueHandle<E>
  package let isPersistent: Bool
  package let isException: Bool

  init(temporary handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = false
  }

  init(persistent value: consuming JSValue<E>) {
    self.handle = value.takeHandle()
    self.isPersistent = true
    self.isException = false
  }

  init(exception handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = true
  }
}

// MARK: - JSInstantContext

// MARK: - Value arena

private final class ScopeArena<Handle: Hashable>: @unchecked Sendable {
  var created: [Handle] = []
  var removed: Set<Handle> = []
}

// MARK: - Shared scope core

struct ScopeCore<E: JSEngine> {
  let driverContextHandle: E.ContextHandle
  private let arena: ScopeArena<E.ValueHandle>

  init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
    self.arena = ScopeArena()
  }

  func drain() {
    for h in arena.created where !arena.removed.contains(h) {
      E.releaseCreatedHandle(h, in: driverContextHandle)
    }
  }

  /// Track an engine-returned owning handle (a value-operation result) on
  /// this scope's arena so its drain releases it.
  func track(_ handle: E.ValueHandle) {
    arena.created.append(handle)
  }

  func makeString(_ value: String) -> JSCallbackValue<E> {
    guard let h = E.makeStringValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeString failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h, context: driverContextHandle)
  }

  func makeString(from keyHandle: E.PropertyStringKeyHandle) -> JSCallbackValue<E> {
    guard
      let handle = E.makeStringValueHandle(
        fromPropertyStringKey: keyHandle,
        in: driverContextHandle
      )
    else {
      preconditionFailure("makeString(from:) failed")
    }
    arena.created.append(handle)
    return JSCallbackValue(handle: handle, context: driverContextHandle)
  }

  func makeNumber(_ value: Double) -> JSCallbackValue<E> {
    guard let h = E.makeNumberValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeNumber failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h, context: driverContextHandle)
  }

  func makeBoolean(_ value: Bool) -> JSCallbackValue<E> {
    guard let h = E.makeBooleanValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeBoolean failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h, context: driverContextHandle)
  }

  func makeNull() -> JSCallbackValue<E> {
    guard let h = E.makeNullValueHandle(driverContextHandle) else {
      preconditionFailure("makeNull failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h, context: driverContextHandle)
  }

  func makeUndefined() -> JSCallbackValue<E> {
    guard let h = E.makeUndefinedValueHandle(driverContextHandle) else {
      preconditionFailure("makeUndefined failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h, context: driverContextHandle)
  }

  func makeSymbol(_ value: String) -> JSCallbackValue<E> {
    guard let h = E.makeSymbolValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeSymbol failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h, context: driverContextHandle)
  }

  func makeObject() -> JSResult<JSCallbackValue<E>> {
    guard let r = E.makeObjectResultHandle(driverContextHandle) else {
      preconditionFailure("makeObject failed")
    }
    switch r {
    case .value(let h):
      arena.created.append(h)
      return .value(JSCallbackValue(handle: h, context: driverContextHandle))
    case .exception(let h):
      arena.created.append(h)
      return .exception(JSCallbackValue(handle: h, context: driverContextHandle))
    }
  }

  func makeArray() -> JSResult<JSCallbackValue<E>> {
    guard let r = E.makeArrayResultHandle(driverContextHandle) else {
      preconditionFailure("makeArray failed")
    }
    switch r {
    case .value(let h):
      arena.created.append(h)
      return .value(JSCallbackValue(handle: h, context: driverContextHandle))
    case .exception(let h):
      arena.created.append(h)
      return .exception(JSCallbackValue(handle: h, context: driverContextHandle))
    }
  }

  func persist(_ value: borrowing JSCallbackValue<E>) -> JSValue<E> {
    arena.removed.insert(value.handle)
    value.handle.retainReference(in: driverContextHandle)
    return JSValue(handleValue: value.handle, in: driverContextHandle)
  }

  func `return`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(temporary: value.handle)
  }
}

/// A callback scope context. Manages scope-stack push/pop on the
/// context-addressed registry (`ScopeStackRegistry`), arena-based value
/// lifecycle, and all value factory methods. Values are released on deinit
/// unless `persist()`ed or returned.
public struct JSInstantContext<E: JSEngine>: ~Copyable {
  private var core: ScopeCore<E>

  public var driverContextHandle: E.ContextHandle { core.driverContextHandle }

  @available(*, noasync)
  package init(handle: E.ContextHandle) {
    self.core = ScopeCore(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<E>.pop(for: driverContextHandle)
  }

  // MARK: - Value factories

  @available(*, noasync)
  public func makeString(_ v: String) -> JSCallbackValue<E> { core.makeString(v) }
  @available(*, noasync)
  public func makeNumber(_ v: Double) -> JSCallbackValue<E> { core.makeNumber(v) }
  @available(*, noasync)
  public func makeBoolean(_ v: Bool) -> JSCallbackValue<E> { core.makeBoolean(v) }
  @available(*, noasync)
  public func makeNull() -> JSCallbackValue<E> { core.makeNull() }
  @available(*, noasync)
  public func makeUndefined() -> JSCallbackValue<E> { core.makeUndefined() }

  @available(*, noasync)
  public func makeNumber(_ value: some BinaryInteger) -> JSCallbackValue<E> {
    makeNumber(Double(value))
  }

  @available(*, noasync)
  package func makeSymbol(_ v: String) -> JSCallbackValue<E> { core.makeSymbol(v) }

  @available(*, noasync)
  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSCallbackValue<E> {
    core.makeString(from: key.borrowHandle(in: self))
  }

  @available(*, noasync)
  public func makeObject() -> JSResult<JSCallbackValue<E>> { core.makeObject() }
  @available(*, noasync)
  public func makeArray() -> JSResult<JSCallbackValue<E>> { core.makeArray() }

  // MARK: - Scope operations

  @available(*, noasync)
  public func persist(_ v: borrowing JSCallbackValue<E>) -> JSValue<E> { core.persist(v) }
  @available(*, noasync)
  public func `return`(_ v: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> { core.return(v) }

  @available(*, noasync)
  public func `throw`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(exception: value.handle)
  }

  @available(*, noasync)
  public func returnUndefined() -> JSCallbackReturn<E> {
    let h = E.makeUndefinedValueHandle(driverContextHandle)!
    return JSCallbackReturn(temporary: h)
  }

  @available(*, noasync)
  public func throwUndefined() -> JSCallbackReturn<E> {
    let h = E.makeUndefinedValueHandle(driverContextHandle)!
    return JSCallbackReturn(exception: h)
  }

  // MARK: - Global object

  @available(*, noasync)
  public func globalObjectValue() -> JSValue<E> {
    guard let handle = E.globalObjectValueHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.globalObjectValue could not create handle")
    }
    return JSValue(handleValue: handle, in: driverContextHandle)
  }

  @available(*, noasync)
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    body(globalObjectValue())
  }

  @available(*, noasync)
  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withGlobalObject { global in
      global.setProperty(value, forKey: key, with: attributes, in: self)
    }
  }

  @available(*, noasync)
  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    withGlobalObject { global in
      global.setProperty(value, forKey: key, using: converter, with: attributes, in: self)
    }
  }

  @available(*, noasync)
  public func getGlobalProperty(forKey key: StaticString) -> JSValue<E> {
    withGlobalObject { global in
      global.getProperty(forKey: key, in: self)
    }
  }

  @available(*, noasync)
  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type
  ) -> C.SwiftType {
    withGlobalObject { global in
      global.getProperty(forKey: key, using: converter, in: self)
    }
  }

  @available(*, noasync)
  public func deleteGlobalProperty(forKey key: StaticString) {
    withGlobalObject { global in
      global.deleteProperty(forKey: key, in: self)
    }
  }

  @available(*, noasync)
  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    withGlobalObject { global in
      global.hasProperty(key, in: self)
    }
  }

  @available(*, noasync)
  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback<E>
  ) where E.Engine == E {
    let function = makeFunction(named: name, callback: callback)
    let key = makePropertyStringKey(name)
    withGlobalObject { global in
      global.setProperty(function, forKey: key, with: attributes, in: self)
    }
  }

  // MARK: - Other operations

  @available(*, noasync)
  public func toBoolean(_ value: borrowing JSValue<E>) -> Bool {
    E.toBooleanForHandle(value.borrowHandle(), in: driverContextHandle)
  }

  @available(*, noasync)
  public func toNumber(_ value: borrowing JSValue<E>) -> Double {
    E.toNumberForHandle(value.borrowHandle(), in: driverContextHandle)
  }

  @available(*, noasync)
  public func toString(_ value: borrowing JSValue<E>) -> String {
    E.toStringForHandle(value.borrowHandle(), in: driverContextHandle) ?? ""
  }

  // setData/data/makePropertyStringKey/prepareScript are deliberately not
  // `noasync`: they are not scope-bound value operations — context data is
  // scope-independent, and property-string-key / prepared-script handles are
  // Sendable and self-owning, valid beyond the scope window.
  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type = K.self) {
    E.contextDataStorageBox(in: driverContextHandle)?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type = K.self) -> K.Value? {
    E.contextDataStorageBox(in: driverContextHandle)?.data(for: key) ?? K.defaultValue
  }

  public func makePropertyStringKey(_ value: String) -> JSPropertyStringKey<E> {
    guard let handle = E.makePropertyStringKeyHandle(value, in: driverContextHandle) else {
      preconditionFailure("JSInstantContext.makePropertyStringKey could not create handle")
    }
    return JSPropertyStringKey(handle: handle, context: driverContextHandle)
  }

  public func prepareScript(_ source: String) -> JSPreparedScript<E> {
    guard let handle = E.makePreparedScriptHandle(source, in: driverContextHandle) else {
      preconditionFailure("JSInstantContext.prepareScript could not create handle")
    }
    return JSPreparedScript(handle: handle, context: driverContextHandle)
  }

  @available(*, noasync)
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    guard
      let handle = E.makeFunctionValueHandle(
        named: name, callback: callback, in: driverContextHandle)
    else {
      preconditionFailure("JSInstantContext.makeFunction could not create handle")
    }
    return JSValue(handleValue: handle, in: driverContextHandle)
  }

  @available(*, noasync)
  public func evaluateScript(
    _ script: borrowing JSPreparedScript<E>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      E.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: self),
        driverContextHandle,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ), in: driverContextHandle
    )
  }

  @available(*, noasync)
  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    let prepared = prepareScript(script)
    return evaluateScript(prepared, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }
}

extension JSInstantContext: JSScopeWitness {
  typealias Engine = E
}
