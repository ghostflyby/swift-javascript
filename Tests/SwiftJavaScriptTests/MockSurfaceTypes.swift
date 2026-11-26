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

  public func asCallArgument() -> MockSurfaceCallArgument {
    MockSurfaceCallArgument(handle: handle)
  }

  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("MockSurfaceValue.type() could not query value type")
    }
    return valueType
  }

  // MARK: - Conversion and equality

  public func toString() -> String {
    contextHandle.toStringForHandle(handle) ?? ""
  }

  public func toNumber() -> Double {
    contextHandle.toNumberForHandle(handle)
  }

  public func toBoolean() -> Bool {
    contextHandle.toBooleanForHandle(handle)
  }

  public func looselyEquals(_ other: borrowing MockSurfaceValue) -> Bool {
    contextHandle.looselyEqualsHandle(handle, other.borrowHandle()) ?? false
  }

  public func strictlyEquals(_ other: borrowing MockSurfaceValue) -> Bool {
    contextHandle.strictlyEqualsHandle(handle, other.borrowHandle()) ?? false
  }
}

/// The mock call-argument token.
///
/// Borrows the value handle: the source value's arena must stay alive for the
/// immediate synchronous call the token is passed to.
public struct MockSurfaceCallArgument: SwiftJavaScript.JSCallArgument {
  let handle: MockValueHandle

  init(handle: MockValueHandle) {
    self.handle = handle
  }

  init(_ value: borrowing MockSurfaceValue) {
    self.handle = value.handle
  }

  init(_ value: borrowing MockSurfaceCallbackValue) {
    self.handle = value.handle
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

  public func asCallArgument() -> MockSurfaceCallArgument {
    MockSurfaceCallArgument(handle: handle)
  }

  @available(*, noasync)
  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("MockSurfaceCallbackValue.type() could not query value type")
    }
    return valueType
  }

  // MARK: - Conversion and equality
  //
  // The callback window's views are `noasync` on the concrete type: they only
  // exist inside a synchronous callback window.

  @available(*, noasync)
  public func toString() -> String {
    contextHandle.toStringForHandle(handle) ?? ""
  }

  @available(*, noasync)
  public func toNumber() -> Double {
    contextHandle.toNumberForHandle(handle)
  }

  @available(*, noasync)
  public func toBoolean() -> Bool {
    contextHandle.toBooleanForHandle(handle)
  }

  @available(*, noasync)
  public func looselyEquals(_ other: borrowing MockSurfaceCallbackValue) -> Bool {
    contextHandle.looselyEqualsHandle(handle, other.borrowHandle()) ?? false
  }

  @available(*, noasync)
  public func strictlyEquals(_ other: borrowing MockSurfaceCallbackValue) -> Bool {
    contextHandle.strictlyEqualsHandle(handle, other.borrowHandle()) ?? false
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
// The value factories, global reads, script evaluation and data access are
// engine-implemented from slice 3 of the dehandle migration: each rides on the
// same handle-level `ScopeCore` the production engines use and adopts every
// engine-created handle on this scope's arena exactly once, so the ledger
// assertions exercise the same shape as the engines. What stays in core is the
// value-level composition (`installGlobalFunction`, the `CallbackValue` global
// write). What remains here is the mock's part: the callback exits, the
// wrappers around handles, and function creation.

extension MockSurfaceInstantContext {
  public func persist(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfaceValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return MockSurfaceValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing MockSurfaceCallbackValue) -> MockSurfaceValue {
    MockSurfaceValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(
    from key: borrowing MockSurfacePropertyStringKey
  ) -> MockSurfaceCallbackValue {
    let contextHandle = core.driverContextHandle
    guard
      let handle = contextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: contextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNumber(_ value: Double) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<MockSurfaceCallbackValue> {
    guard let result = core.driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  public func makeArray() -> JSResult<MockSurfaceCallbackValue> {
    guard let result = core.driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing MockSurfaceInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    try body(self)
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

  public func getGlobalProperty(forKey key: StaticString) -> MockSurfaceValue {
    let contextHandle = core.driverContextHandle
    guard let global = contextHandle.globalObjectValueHandle() else {
      preconditionFailure(
        "MockSurfaceInstantContext.getGlobalProperty could not get global object")
    }
    guard let result = contextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("MockSurfaceInstantContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(MockOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      contextHandle.releaseCreatedHandle(MockOwnedValueHandle.adopting(handle))
      guard let undefined = contextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("MockSurfaceInstantContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing MockSurfaceValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.deleteStaticStringPropertyHandle(key, on: global)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else {
      return false
    }
    return core.driverContextHandle.hasStaticStringPropertyHandle(key, on: global) ?? false
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

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing MockSurfacePreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<MockSurfaceValue> {
    let contextHandle = core.driverContextHandle
    guard
      let result = contextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: contextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("MockSurfaceInstantContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    core.driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    core.driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
}

extension MockSurfaceScope {
  public func persist(
    _ value: borrowing MockSurfaceCallbackValue
  ) -> MockSurfaceValue {
    core.transferToDefaultFrame(value.borrowHandle())
    return MockSurfaceValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  @available(*, noasync)
  public func localValue(_ value: borrowing MockSurfaceCallbackValue) -> MockSurfaceValue {
    MockSurfaceValue(handle: value.borrowHandle(), contextHandle: core.driverContextHandle)
  }

  // MARK: - Value factories

  public func makeString(_ value: String) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeString(
    from key: borrowing MockSurfacePropertyStringKey
  ) -> MockSurfaceCallbackValue {
    let contextHandle = core.driverContextHandle
    guard
      let handle = contextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: contextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNumber(_ value: Double) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeNull() -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeUndefined() -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeSymbol(_ value: String) -> MockSurfaceCallbackValue {
    guard let handle = core.driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbolValueHandle failed")
    }
    return adoptCallbackHandle(handle)
  }

  public func makeObject() -> JSResult<MockSurfaceCallbackValue> {
    guard let result = core.driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  public func makeArray() -> JSResult<MockSurfaceCallbackValue> {
    guard let result = core.driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCallbackHandle(handle))
    case .exception(let handle):
      return .exception(adoptCallbackHandle(handle))
    }
  }

  // MARK: - Instant window

  public func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing MockSurfaceInstantContext) throws(Failure) -> R
  ) throws(Failure) -> R {
    let window = MockSurfaceInstantContext(handle: core.driverContextHandle)
    return try body(window)
  }

  public func globalObjectValue() -> MockSurfaceValue {
    guard let handle = core.driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("MockSurfaceScope.globalObjectValue could not get global object")
    }
    return MockSurfaceValue(handle: handle, contextHandle: core.driverContextHandle)
  }

  public func getGlobalProperty(forKey key: StaticString) -> MockSurfaceValue {
    let contextHandle = core.driverContextHandle
    guard let global = contextHandle.globalObjectValueHandle() else {
      preconditionFailure("MockSurfaceScope.getGlobalProperty could not get global object")
    }
    guard let result = contextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("MockSurfaceScope.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(MockOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      contextHandle.releaseCreatedHandle(MockOwnedValueHandle.adopting(handle))
      guard let undefined = contextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("MockSurfaceScope could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing MockSurfaceValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else { return }
    _ = core.driverContextHandle.deleteStaticStringPropertyHandle(key, on: global)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = core.driverContextHandle.globalObjectValueHandle() else {
      return false
    }
    return core.driverContextHandle.hasStaticStringPropertyHandle(key, on: global) ?? false
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

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing MockSurfacePreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<MockSurfaceValue> {
    let contextHandle = core.driverContextHandle
    guard
      let result = contextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: contextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("MockSurfaceScope.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    core.driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    core.driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
}

// MARK: - Property, object, and classification operations
//
// Engine-implemented from slice 2 of the dehandle migration: every operation
// drives `MockContextHandle` directly and adopts each engine-returned handle
// on the addressed arena exactly once — the exception path included — so the
// scope-drain ledger matches the production engines.

extension MockSurfaceValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    let contextHandle = context.driverContextHandle
    return bridgeSurfaceHandleResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getIndexPropertyHandle(at: UInt32(index), on: handle),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing MockSurfaceValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing MockSurfaceValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing MockSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.setIndexPropertyHandle(
      at: UInt32(index),
      on: handle,
      to: value.borrowHandle()
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: handle)
  }

  public func deleteProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: handle) ?? false
  }

  public func hasProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    ) ?? false
  }

  public func propertyNames(in context: borrowing MockSurfaceInstantContext) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: handle) ?? []
  }

  // MARK: Object conversion and classification

  public func toObject(
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.toObjectHandle(handle),
      in: context
    )
  }

  public func isArray(in context: borrowing MockSurfaceInstantContext) -> Bool {
    context.driverContextHandle.isArrayHandle(handle) ?? false
  }

  public func isDate(in context: borrowing MockSurfaceInstantContext) -> Bool {
    context.driverContextHandle.isDateHandle(handle) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing MockSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: borrowing MockSurfaceInstantContext) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(handle)
  }

  public func isTypedArray(in context: borrowing MockSurfaceInstantContext) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(handle) != nil
  }

  // MARK: Callback-value parameters

  public func setProperty(
    _ key: StaticString,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func isInstanceOf(
    _ constructor: borrowing MockSurfaceCallbackValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }
}

// MARK: - Invocation operations
//
// The five call operations are engine-implemented from slice 1 of the
// dehandle migration: each token maps back to its borrowed handle, and every
// engine result — value and exception alike — is adopted through the shared
// bridge exactly once, so the scope-drain ledger matches the other value
// operations.

extension MockSurfaceValue {
  public func call(
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: nil,
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing MockSurfaceValue,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing MockSurfaceCallbackValue,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func construct(
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.constructHandle(handle, argumentHandles: arguments.map(\.handle)),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    switch bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(name, on: handle),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: handle,
          argumentHandles: arguments.map(\.handle)
        ),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing MockSurfacePropertyStringKey,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    let contextHandle = context.driverContextHandle
    switch bridgeSurfaceHandleResult(
      contextHandle.getPropertyStringKeyHandle(
        name.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: handle,
          argumentHandles: arguments.map(\.handle)
        ),
        in: context
      )
    }
  }
}

// MARK: - `#isolation` value conveniences
//
// The same operations addressed through the context actor. A requirement
// cannot carry a default argument, so these same-name overloads keep
// `value.getProperty("x")` callable; their results are adopted onto the
// context default scope exactly once (exception included), so they outlive the
// synchronous call instead of draining with a window.

extension MockSurfaceValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    let contextHandle = context.driverContextHandle
    return bridgeSurfaceHandleResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getIndexPropertyHandle(at: UInt32(index), on: handle),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing MockSurfaceValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing MockSurfaceValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing MockSurfaceValue,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setIndexPropertyHandle(
      at: UInt32(index),
      on: handle,
      to: value.borrowHandle()
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: handle)
  }

  public func deleteProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: handle) ?? false
  }

  public func hasProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    ) ?? false
  }

  public func propertyNames(in context: isolated MockSurfaceContext = #isolation) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: handle) ?? []
  }

  // MARK: Object conversion and classification

  public func toObject(
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.toObjectHandle(handle),
      in: context
    )
  }

  public func isArray(in context: isolated MockSurfaceContext = #isolation) -> Bool {
    context.driverContextHandle.isArrayHandle(handle) ?? false
  }

  public func isDate(in context: isolated MockSurfaceContext = #isolation) -> Bool {
    context.driverContextHandle.isDateHandle(handle) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing MockSurfaceValue,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: isolated MockSurfaceContext = #isolation) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(handle)
  }

  public func isTypedArray(in context: isolated MockSurfaceContext = #isolation) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(handle) != nil
  }

  // MARK: Callback-value parameters

  public func setProperty(
    _ key: StaticString,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func isInstanceOf(
    _ constructor: borrowing MockSurfaceCallbackValue,
    in context: isolated MockSurfaceContext = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  // MARK: Invocation

  public func call(
    arguments: [MockSurfaceCallArgument] = [],
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: nil,
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing MockSurfaceValue,
    arguments: [MockSurfaceCallArgument] = [],
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing MockSurfaceCallbackValue,
    arguments: [MockSurfaceCallArgument] = [],
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func construct(
    arguments: [MockSurfaceCallArgument] = [],
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.constructHandle(handle, argumentHandles: arguments.map(\.handle)),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [MockSurfaceCallArgument] = [],
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    switch bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(name, on: handle),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: handle,
          argumentHandles: arguments.map(\.handle)
        ),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing MockSurfacePropertyStringKey,
    arguments: [MockSurfaceCallArgument] = [],
    in context: isolated MockSurfaceContext = #isolation
  ) -> JSResult<MockSurfaceValue> {
    let contextHandle = context.driverContextHandle
    switch bridgeSurfaceHandleResult(
      contextHandle.getPropertyStringKeyHandle(
        name.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: handle,
          argumentHandles: arguments.map(\.handle)
        ),
        in: context
      )
    }
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
  public typealias Class = MockSurfaceClass
  public typealias CallArgument = MockSurfaceCallArgument
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
  //
  // Engine internals: every context-level operation below creates or settles
  // an engine reference on the context default scope through these two.

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

  // MARK: - Value factories

  public func makeString(_ value: String) -> MockSurfaceValue {
    guard let handle = driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeString(
    from key: borrowing MockSurfacePropertyStringKey
  ) -> MockSurfaceValue {
    guard
      let handle = driverContextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: driverContextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNumber(_ value: Double) -> MockSurfaceValue {
    guard let handle = driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> MockSurfaceValue {
    guard let handle = driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNull() -> MockSurfaceValue {
    guard let handle = driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeUndefined() -> MockSurfaceValue {
    guard let handle = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeObject() -> MockSurfaceValue {
    guard let result = driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("MockSurfaceContext.makeObject failed")
    }
  }

  public func makeArray() -> MockSurfaceValue {
    guard let result = driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("MockSurfaceContext.makeArray failed")
    }
  }

  /// The creation reference is adopted by the context default scope, so the
  /// function outlives any single window.
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<MockSurfaceInstantContext>
  ) -> MockSurfaceValue {
    guard
      let handle = driverContextHandle.makeFunctionValueHandle(named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    return adoptCreatedHandle(handle)
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

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> MockSurfaceValue {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("MockSurfaceContext.getGlobalProperty could not get global object")
    }
    guard let result = driverContextHandle.getStaticStringPropertyHandle(key, on: global) else {
      preconditionFailure("MockSurfaceContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(MockOwnedValueHandle.adopting(handle))
    case .exception(let handle):
      driverContextHandle.releaseCreatedHandle(MockOwnedValueHandle.adopting(handle))
      guard let undefined = driverContextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("MockSurfaceContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing MockSurfaceValue,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  ) {
    guard let global = driverContextHandle.globalObjectValueHandle() else { return }
    _ = driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: global,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteGlobalProperty(forKey key: StaticString) {
    guard let global = driverContextHandle.globalObjectValueHandle() else { return }
    _ = driverContextHandle.deleteStaticStringPropertyHandle(key, on: global)
  }

  public func hasGlobalProperty(_ key: StaticString) -> Bool {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      return false
    }
    return driverContextHandle.hasStaticStringPropertyHandle(key, on: global) ?? false
  }

  // MARK: - Scripts

  public func evaluateScript(
    _ script: borrowing MockSurfacePreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<MockSurfaceValue> {
    guard
      let result = driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("MockSurfaceContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
    }
  }

  // MARK: - Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
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
  public typealias Value = MockSurfaceValue
  public typealias InstantContext = MockSurfaceInstantContext

  let value: MockSurfaceValue

  init(value: consuming MockSurfaceValue) {
    self.value = value
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

  // MARK: - Bytes

  public var byteLength: Int {
    guard
      let length = value.contextHandle.arrayBufferByteLengthForHandle(
        value.borrowHandle()
      )
    else {
      preconditionFailure("Failed to read ArrayBuffer byteLength")
    }
    return length
  }

  public var bytes: [UInt8] {
    withUnsafeBytes { Array($0) }
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(
    _ body: (UnsafeRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = value.contextHandle.arrayBufferBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access ArrayBuffer bytes")
    }
    return body(UnsafeRawBufferPointer(start: access.bytes, count: byteLength))
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = value.contextHandle.arrayBufferBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable ArrayBuffer bytes")
    }
    return body(UnsafeMutableRawBufferPointer(start: access.bytes, count: byteLength))
  }
}

public struct MockSurfaceTypedArray: SwiftJavaScript.JSTypedArray, ~Copyable {
  public typealias Context = MockSurfaceContext
  public typealias Value = MockSurfaceValue
  public typealias InstantContext = MockSurfaceInstantContext
  public typealias Buffer = MockSurfaceArrayBuffer

  let value: MockSurfaceValue

  init(value: consuming MockSurfaceValue) {
    self.value = value
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

    let bufferHandle = buffer.value.borrowHandle()
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

  // MARK: - Shape

  public var kind: JSTypedArrayKind {
    guard
      let kind = value.contextHandle.typedArrayKindForHandle(value.borrowHandle())
    else {
      preconditionFailure("Wrapped value is not a TypedArray")
    }
    return kind
  }

  public var length: Int {
    guard
      let length = value.contextHandle.typedArrayLengthForHandle(value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray length")
    }
    return length
  }

  public var byteLength: Int {
    guard
      let byteLength = value.contextHandle.typedArrayByteLengthForHandle(
        value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray byteLength")
    }
    return byteLength
  }

  public var byteOffset: Int {
    guard
      let byteOffset = value.contextHandle.typedArrayByteOffsetForHandle(
        value.borrowHandle())
    else {
      preconditionFailure("Failed to read TypedArray byteOffset")
    }
    return byteOffset
  }

  public var buffer: MockSurfaceArrayBuffer {
    let contextHandle = value.contextHandle
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

  // MARK: - Bytes

  public var bytes: [UInt8] {
    withUnsafeBytes { Array($0) }
  }

  public borrowing func withUnsafeBytes<R: ~Copyable>(
    _ body: (UnsafeRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = value.contextHandle.typedArrayBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    return body(UnsafeRawBufferPointer(start: start, count: byteLength))
  }

  public borrowing func withUnsafeMutableBytes<R: ~Copyable>(
    _ body: (UnsafeMutableRawBufferPointer) -> R
  ) -> R {
    let byteLength = self.byteLength
    let access = value.contextHandle.typedArrayBytesPtrForHandle(value.borrowHandle())
    guard !access.hadException else {
      preconditionFailure("Failed to access mutable TypedArray bytes")
    }
    let start = access.bytes?.advanced(by: byteOffset)
    return body(UnsafeMutableRawBufferPointer(start: start, count: byteLength))
  }
}

extension MockSurfaceInstantContext: JSArrayBufferHostScope {
  package func adoptArrayBufferBytesNoCopy(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator:
      @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
      ) -> Void,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> MockSurfaceValue? {
    guard
      let handle = driverContextHandle.makeArrayBufferWithBytesNoCopyHandle(
        bytes: bytes,
        byteLength: byteLength,
        bytesDeallocator: bytesDeallocator,
        deallocatorContext: deallocatorContext
      )
    else {
      return nil
    }
    return adoptCreatedHandle(MockOwnedValueHandle.adopting(handle))
  }
}

/// The mock context's class. `MockClass` is the raw value model, so the
/// class gets its own name and wraps the existing class handle.
public final class MockSurfaceClass: SwiftJavaScript.JSClass, @unchecked Sendable {
  public typealias Context = MockSurfaceContext

  let rawHandle: MockClassHandle

  init(classHandle: MockClassHandle) {
    self.rawHandle = classHandle
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
    identity: ObjectIdentifier,
    in context: borrowing MockSurfaceInstantContext
  ) -> MockSurfaceClass {
    _ = identity
    _ = context
    return MockSurfaceClass(
      classHandle: MockClassHandle(rawClass: MockClass(id: definition.className ?? "")))
  }

  public static func makeHostObject(
    of jsClass: MockSurfaceClass,
    privateData: UnsafeMutableRawPointer,
    in context: borrowing MockSurfaceInstantContext
  ) -> MockSurfaceValue? {
    _ = jsClass
    _ = privateData
    _ = context
    return nil
  }

  public static func hostObjectPrivateData(
    of value: borrowing MockSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> UnsafeMutableRawPointer? {
    _ = value
    _ = context
    return nil
  }
}

// MARK: - Compile-time context checks

/// `MockSurfaceContext` names every type of the mock; this sink compiles only
/// while the mock's types are exactly the ones its context associates (see
/// `SurfaceConformanceTests` in the cross-engine target for the same shape).
private func checkContextAssociations<C: SwiftJavaScript.JSContext>(
  _: C.Type,
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
  callArgument: C.CallArgument.Type,
  jsClass: C.Class.Type
) {}

@Test func mockSurfaceSatisfiesContextEquations() {
  checkContextAssociations(
    MockSurfaceContext.self,
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
    callArgument: MockSurfaceCallArgument.self,
    jsClass: MockSurfaceClass.self
  )
}

// MARK: - Engine-local result bridging
//
// The core bridge was deleted with the value-level Codable rewrite; the mock
// keeps the same shape on its own arena, so every operation result is adopted
// exactly once (value and exception alike).

private func bridgeSurfaceHandleResult(
  _ result: JSResult<MockValueHandle>?,
  in context: borrowing MockSurfaceInstantContext
) -> JSResult<MockSurfaceValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
  }
}

private func bridgeSurfaceHandleResult(
  _ result: JSResult<MockValueHandle>?,
  in context: isolated MockSurfaceContext
) -> JSResult<MockSurfaceValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(MockOwnedValueHandle.adopting(handle)))
  }
}
