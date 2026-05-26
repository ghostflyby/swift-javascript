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

private final class RegistrySentinel: NSObject, @unchecked Sendable {}
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

  static func push(_ context: any JSContextManualReferenceCountedHandle, key: AnyHashable) {
    let reg = registry()
    reg.activeContext = key
    let s = reg.stacks[key] ?? ScopeStack()
    s.push(context)
    reg.stacks[key] = s
  }

  @discardableResult
  static func pop(key: AnyHashable) -> (any JSContextManualReferenceCountedHandle)? {
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

  package init(temporary handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = false
  }

  package init(persistent value: consuming JSValue<E>) {
    self.handle = value.takeHandle()
    self.isPersistent = true
    self.isException = false
  }

  package init(exception handle: JSValueHandle<E>) {
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

/// A callback scope context. Manages TLS push/pop, arena-based value lifecycle,
/// and all value factory methods. Values are released on deinit unless
/// `persist()`ed or returned.
public struct JSInstantContext<E: JSEngine>: ~Copyable {
  public let driverContextHandle: E.ContextHandle
  private let arena: ScopeArena<E.ValueHandle>
  private let contextKey: AnyHashable

  package init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
    self.arena = ScopeArena()
    self.contextKey = AnyHashable(handle)
    TLSCallbackStack.push(handle, key: contextKey)
  }

  deinit {
    for h in arena.created where !arena.removed.contains(h) {
      E.releaseCreatedHandle(h, in: driverContextHandle)
    }
    TLSCallbackStack.pop(key: contextKey)
  }

  // MARK: - Arena tracking

  // MARK: - Value factories

  private func callbackValue(from handle: E.ValueHandle) -> JSCallbackValue<E> {
    JSCallbackValue(handle: handle)
  }

  public func makeString(_ value: String) -> JSCallbackValue<E> {
    guard let handle = E.makeStringValueHandle(value, driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeString could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeNumber(_ value: Double) -> JSCallbackValue<E> {
    guard let handle = E.makeNumberValueHandle(value, driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeNumber could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeBoolean(_ value: Bool) -> JSCallbackValue<E> {
    guard let handle = E.makeBooleanValueHandle(value, driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeBoolean could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeNull() -> JSCallbackValue<E> {
    guard let handle = E.makeNullValueHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeNull could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeUndefined() -> JSCallbackValue<E> {
    guard let handle = E.makeUndefinedValueHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeUndefined could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSCallbackValue<E> {
    makeNumber(Double(value))
  }

  package func makeSymbol(_ value: String) -> JSCallbackValue<E> {
    guard let handle = E.makeSymbolValueHandle(value, driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeSymbol could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSCallbackValue<E> {
    guard let handle = E.makeStringValueHandle(
      fromPropertyStringKey: key.borrowHandle(in: self),
      in: driverContextHandle
    ) else {
      preconditionFailure("JSInstantContext.makeString(from:) could not create handle")
    }
    arena.created.append(handle)
    return callbackValue(from: handle)
  }

  public func makeObject() -> JSResult<JSCallbackValue<E>> {
    guard let result = E.makeObjectResultHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeObject could not create handle")
    }
    switch result {
    case .value(let handle):
      arena.created.append(handle)
      return .value(callbackValue(from: handle))
    case .exception(let handle):
      return .exception(callbackValue(from: handle))
    }
  }

  public func makeArray() -> JSResult<JSCallbackValue<E>> {
    guard let result = E.makeArrayResultHandle(driverContextHandle) else {
      preconditionFailure("JSInstantContext.makeArray could not create handle")
    }
    switch result {
    case .value(let handle):
      arena.created.append(handle)
      return .value(callbackValue(from: handle))
    case .exception(let handle):
      return .exception(callbackValue(from: handle))
    }
  }

  // MARK: - Scope operations

  public func persist(_ value: borrowing JSCallbackValue<E>) -> JSValue<E> {
    arena.removed.insert(value.handle)
    value.handle.retainReference(in: driverContextHandle)
    return JSValue(handleValue: value.handle, in: driverContextHandle)
  }

  public func `return`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(temporary: value.handle)
  }

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
    guard let handle = E.makeFunctionValueHandle(named: name, callback: callback, in: driverContextHandle) else {
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
