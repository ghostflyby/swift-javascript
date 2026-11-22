import Foundation

// MARK: - Scope stack infrastructure

/// Per-thread LIFO stack of callback context handles.
internal final class ScopeStack: @unchecked Sendable {
  private var frames: [any JSContextManualReferenceCountedHandle] = []

  func push(_ context: any JSContextManualReferenceCountedHandle) { frames.append(context) }
  @discardableResult
  func pop() -> (any JSContextManualReferenceCountedHandle)? { frames.popLast() }
  var top: (any JSContextManualReferenceCountedHandle)? { frames.last }
  var isEmpty: Bool { frames.isEmpty }
}

/// Per-thread registry of per-context scope stacks and the active context.
private final class RuntimeScopeRegistry: NSObject, @unchecked Sendable {
  var stacks: [AnyHashable: ScopeStack] = [:]
  var activeContext: AnyHashable?
}

private final class RegistrySentinel: NSObject, NSCopying, @unchecked Sendable {
  func copy(with zone: NSZone? = nil) -> Any { return self }
}
private let registrySentinel = RegistrySentinel()

internal enum TLSCallbackStack {

  private static func tlsDictionary() -> NSMutableDictionary {
    Thread.current.threadDictionary
  }

  private static func registry() -> RuntimeScopeRegistry {
    if let existing = tlsDictionary()[registrySentinel] as? RuntimeScopeRegistry {
      return existing
    }
    let new = RuntimeScopeRegistry()
    tlsDictionary()[registrySentinel] = new
    return new
  }

  static func push(_ context: any JSContextManualReferenceCountedHandle) {
    let key = AnyHashable(context)
    let reg = registry()
    reg.activeContext = key
    let s = reg.stacks[key] ?? ScopeStack()
    s.push(context)
    reg.stacks[key] = s
  }

  @discardableResult
  static func pop(_ context: any JSContextManualReferenceCountedHandle) -> (
    any JSContextManualReferenceCountedHandle
  )? {
    let key = AnyHashable(context)
    let reg = registry()
    guard let s = reg.stacks[key] else { return nil }
    let popped = s.pop()
    if s.isEmpty {
      reg.stacks.removeValue(forKey: key)
      reg.activeContext = nil
    }
    return popped
  }

  static var top: (any JSContextManualReferenceCountedHandle)? {
    let reg = registry()
    guard let active = reg.activeContext,
      let s = reg.stacks[active]
    else { return nil }
    return s.top
  }
}

internal func isInsideCallbackScope<E: JSEngine>(for _: E.Type) -> Bool {
  TLSCallbackStack.top != nil
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

  func makeString(_ value: String) -> JSCallbackValue<E> {
    guard let h = E.makeStringValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeString failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h)
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
    return JSCallbackValue(handle: handle)
  }

  func makeNumber(_ value: Double) -> JSCallbackValue<E> {
    guard let h = E.makeNumberValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeNumber failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h)
  }

  func makeBoolean(_ value: Bool) -> JSCallbackValue<E> {
    guard let h = E.makeBooleanValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeBoolean failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h)
  }

  func makeNull() -> JSCallbackValue<E> {
    guard let h = E.makeNullValueHandle(driverContextHandle) else {
      preconditionFailure("makeNull failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h)
  }

  func makeUndefined() -> JSCallbackValue<E> {
    guard let h = E.makeUndefinedValueHandle(driverContextHandle) else {
      preconditionFailure("makeUndefined failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h)
  }

  func makeSymbol(_ value: String) -> JSCallbackValue<E> {
    guard let h = E.makeSymbolValueHandle(value, driverContextHandle) else {
      preconditionFailure("makeSymbol failed")
    }
    arena.created.append(h)
    return JSCallbackValue(handle: h)
  }

  func makeObject() -> JSResult<JSCallbackValue<E>> {
    guard let r = E.makeObjectResultHandle(driverContextHandle) else {
      preconditionFailure("makeObject failed")
    }
    switch r {
    case .value(let h):
      arena.created.append(h)
      return .value(JSCallbackValue(handle: h))
    case .exception(let h):
      return .exception(JSCallbackValue(handle: h))
    }
  }

  func makeArray() -> JSResult<JSCallbackValue<E>> {
    guard let r = E.makeArrayResultHandle(driverContextHandle) else {
      preconditionFailure("makeArray failed")
    }
    switch r {
    case .value(let h):
      arena.created.append(h)
      return .value(JSCallbackValue(handle: h))
    case .exception(let h):
      return .exception(JSCallbackValue(handle: h))
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

/// A callback scope context. Manages TLS push/pop, arena-based value lifecycle,
/// and all value factory methods. Values are released on deinit unless
/// `persist()`ed or returned.
public struct JSInstantContext<E: JSEngine>: ~Copyable {
  private var core: ScopeCore<E>

  public var driverContextHandle: E.ContextHandle { core.driverContextHandle }

  package init(handle: E.ContextHandle) {
    self.core = ScopeCore(handle: handle)
    TLSCallbackStack.push(handle)
  }

  deinit {
    core.drain()
    TLSCallbackStack.pop(driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ v: String) -> JSCallbackValue<E> { core.makeString(v) }
  public func makeNumber(_ v: Double) -> JSCallbackValue<E> { core.makeNumber(v) }
  public func makeBoolean(_ v: Bool) -> JSCallbackValue<E> { core.makeBoolean(v) }
  public func makeNull() -> JSCallbackValue<E> { core.makeNull() }
  public func makeUndefined() -> JSCallbackValue<E> { core.makeUndefined() }

  public func makeNumber(_ value: some BinaryInteger) -> JSCallbackValue<E> {
    makeNumber(Double(value))
  }

  package func makeSymbol(_ v: String) -> JSCallbackValue<E> { core.makeSymbol(v) }

  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSCallbackValue<E> {
    core.makeString(from: key.borrowHandle(in: self))
  }

  public func makeObject() -> JSResult<JSCallbackValue<E>> { core.makeObject() }
  public func makeArray() -> JSResult<JSCallbackValue<E>> { core.makeArray() }

  // MARK: - Scope operations

  public func persist(_ v: borrowing JSCallbackValue<E>) -> JSValue<E> { core.persist(v) }
  public func `return`(_ v: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> { core.return(v) }

  public func `throw`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(exception: value.handle)
  }

  public func returnUndefined() -> JSCallbackReturn<E> {
    let h = E.makeUndefinedValueHandle(driverContextHandle)!
    return JSCallbackReturn(temporary: h)
  }

  public func throwUndefined() -> JSCallbackReturn<E> {
    let h = E.makeUndefinedValueHandle(driverContextHandle)!
    return JSCallbackReturn(exception: h)
  }

  // MARK: - Global object

  public func globalObjectValue() -> JSValue<E> {
    guard let handle = E.globalObjectValueHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.globalObjectValue could not create handle")
    }
    return JSValue(handleValue: handle, in: driverContextHandle)
  }

  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    body(globalObjectValue())
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withGlobalObject { global in
      global.setProperty(value, forKey: key, with: attributes, in: self)
    }
  }

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

  public func getGlobalProperty(forKey key: StaticString) -> JSValue<E> {
    withGlobalObject { global in
      global.getProperty(forKey: key, in: self)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type
  ) -> C.SwiftType {
    withGlobalObject { global in
      global.getProperty(forKey: key, using: converter, in: self)
    }
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    withGlobalObject { global in
      global.deleteProperty(forKey: key, in: self)
    }
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    withGlobalObject { global in
      global.hasProperty(key, in: self)
    }
  }

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

  public func toBoolean(_ value: borrowing JSValue<E>) -> Bool {
    E.toBooleanForHandle(value.borrowHandle(), in: driverContextHandle)
  }

  public func toNumber(_ value: borrowing JSValue<E>) -> Double {
    E.toNumberForHandle(value.borrowHandle(), in: driverContextHandle)
  }

  public func toString(_ value: borrowing JSValue<E>) -> String {
    E.toStringForHandle(value.borrowHandle(), in: driverContextHandle) ?? ""
  }

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

  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    let prepared = prepareScript(script)
    return evaluateScript(prepared, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }
}
