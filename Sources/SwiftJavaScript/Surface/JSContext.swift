/// The engine context actor.
///
/// The concrete type is the engine's context (`JSCContext`, `QJSContext`);
/// core keeps the shared default-scope/registry/data-box lifecycle in
/// `JSContextStorage<ContextHandle>`. The public surface only adds the ledger
/// primitives that produce a local view from an engine handle, plus the
/// context-level factories, global access, script evaluation, and data storage
/// that the concrete actor forwards to its instant context or storage.
///
/// The context is the one place that names every user-facing type of an
/// engine, so it is also the anchor for code written against "some engine":
/// generic code takes `C: JSContext` and reaches the rest through `C.Value`,
/// `C.InstantContext`, ...
///
/// Every relationship between an engine's types is stated here exactly once
/// and in one direction, from the context to its member types. The member
/// protocols (`JSValue`, `JSInstantContext`, ...) state no relationships of
/// their own: each names the context it belongs to and aliases the member
/// types it uses. Restating these equalities on the members, or pinning
/// members back onto each other, makes the type checker fail to terminate.
///
/// One consequence for generic code: take the context (`C: JSContext`) as the
/// root whenever values are involved, and use `C.InstantContext`/`C.Scope` as
/// the window types. A bare window type (`S: JSInstantContext`) only knows
/// that it belongs to *some* `S.Context`; it cannot show that it is that
/// context's own window, so `S.Value`'s operations — addressed in
/// `S.Value.InstantContext` — do not accept an `S`. The window's own
/// operations (factories, global access, scripts) do work on a bare `S`.
public protocol JSContext: Actor, Hashable {
  /// The context identity every operation of this context is addressed
  /// through.
  associatedtype ContextHandle: JSScopeContextHandle
  where ContextHandle.InstantContext == InstantContext
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle == ContextHandle.ValueHandle
  associatedtype OwnedValueHandle: JSOwnedValueManualReferenceCountedHandle & ~Copyable
  where OwnedValueHandle == ContextHandle.OwnedValueHandle
  associatedtype VirtualMachine: JSVirtualMachine
  where
    VirtualMachine.Context == Self,
    VirtualMachine.ContextHandle == ContextHandle
  associatedtype Value: JSValue & ~Copyable
  where
    Value.Context == Self,
    Value.ContextHandle == ContextHandle,
    Value.ValueHandle == ValueHandle,
    Value.InstantContext == InstantContext
  associatedtype CallbackValue: JSCallbackValue & ~Copyable
  where
    CallbackValue.Context == Self,
    CallbackValue.ContextHandle == ContextHandle,
    CallbackValue.ValueHandle == ValueHandle
  associatedtype CallbackReturn: JSCallbackReturn & ~Copyable
  where
    CallbackReturn.Context == Self,
    CallbackReturn.ValueHandle == ValueHandle
  associatedtype CallbackArguments: JSCallbackArguments & ~Copyable
  where
    CallbackArguments.Context == Self,
    CallbackArguments.Value == CallbackValue,
    CallbackArguments.InstantContext == InstantContext
  associatedtype Arguments: JSArguments & ~Copyable
  where
    Arguments.Context == Self,
    Arguments.Value == Value,
    Arguments.InstantContext == InstantContext
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where
    InstantContext.Context == Self,
    InstantContext.ContextHandle == ContextHandle,
    InstantContext.Value == Value,
    InstantContext.CallbackValue == CallbackValue,
    InstantContext.CallbackReturn == CallbackReturn,
    InstantContext.CallbackArguments == CallbackArguments,
    InstantContext.Arguments == Arguments,
    InstantContext.PropertyStringKey == PropertyStringKey,
    InstantContext.PreparedScript == PreparedScript,
    InstantContext.PersistentHandle == PersistentHandle
  /// The manual scope shares every member type with the instant context.
  associatedtype Scope: JSScope & ~Copyable
  where
    Scope.Context == Self,
    Scope.ContextHandle == ContextHandle,
    Scope.InstantContext == InstantContext,
    Scope.Value == Value,
    Scope.CallbackValue == CallbackValue,
    Scope.PropertyStringKey == PropertyStringKey,
    Scope.PreparedScript == PreparedScript,
    Scope.PersistentHandle == PersistentHandle
  associatedtype PersistentHandle: JSPersistentHandle
  associatedtype PropertyStringKey: JSPropertyStringKey & ~Copyable
  where
    PropertyStringKey.Context == Self,
    PropertyStringKey.ContextHandle == ContextHandle,
    PropertyStringKey.Handle == ContextHandle.PropertyStringKeyHandle
  associatedtype PreparedScript: JSPreparedScript & ~Copyable
  where
    PreparedScript.Context == Self,
    PreparedScript.ContextHandle == ContextHandle,
    PreparedScript.Handle == ContextHandle.PreparedScriptHandle
  associatedtype ArrayBuffer: JSArrayBuffer & ~Copyable
  where
    ArrayBuffer.Context == Self,
    ArrayBuffer.ContextHandle == ContextHandle,
    ArrayBuffer.Value == Value,
    ArrayBuffer.InstantContext == InstantContext
  associatedtype TypedArray: JSTypedArray & ~Copyable
  where
    TypedArray.Context == Self,
    TypedArray.ContextHandle == ContextHandle,
    TypedArray.Value == Value,
    TypedArray.InstantContext == InstantContext,
    TypedArray.Buffer == ArrayBuffer
  associatedtype ClassHandle: JSClassManualReferenceCountedHandle
  associatedtype Class: JSClass
  where
    Class.Context == Self,
    Class.ClassHandle == ClassHandle

  /// Create a context on `virtualMachine`, with its own engine context handle,
  /// default scope, and persistent registry.
  init(virtualMachine: VirtualMachine)

  /// The context identity every operation of this context is addressed
  /// through. Nonisolated because it is an immutable identity token.
  nonisolated var driverContextHandle: ContextHandle { get }

  /// The VM that owns the runtime this context runs on. Nonisolated for the
  /// same reason as the handle: it is immutable identity.
  nonisolated var virtualMachine: VirtualMachine { get }

  /// The VM's serial executor, the one this actor runs on.
  nonisolated var unownedExecutor: UnownedSerialExecutor { get }

  // MARK: - Synchronous scopes

  /// Run `body` in a synchronous callback window on this context.
  func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing InstantContext) throws(Failure) -> R
  ) throws(Failure) -> R

  /// Open a manual scope nested on this context's scope stack. The scope is
  /// born, used and drained inside this context's isolation — on the VM
  /// thread — which is the witness guarantee its mint/resolve entry points
  /// rely on.
  func makeScope() -> Scope

  // MARK: - Ledger primitives

  /// Adopt an engine-created owning handle into the context default scope and
  /// return the local view. The handle is tracked exactly once, so the
  /// default scope's drain settles the creation reference.
  func adoptCreatedHandle(_ handle: consuming OwnedValueHandle) -> Value

  /// Claim an owned reference for a borrowed handle that no arena owns yet,
  /// track it exactly once on the context default scope, and return the local
  /// view.
  func anchorBorrowedHandle(_ handle: ValueHandle) -> Value

  // MARK: - Persistent bindings

  /// Mint a persistent binding for one value of this context. Minting takes an
  /// independent reference (claim + explicit root); the source value stays
  /// valid for the rest of its window.
  func makePersistentHandle(
    _ value: borrowing Value
  ) -> PersistentHandle

  /// Resolve a handle into a local view anchored on the context default scope.
  /// Returns `nil` for a dead, foreign, or already-closed binding.
  func resolve(_ handle: PersistentHandle) -> Value?

  // MARK: - Value factories

  func makeString(_ value: String) -> Value
  func makeString(from key: borrowing PropertyStringKey) -> Value
  func makeNumber(_ value: Double) -> Value
  func makeBoolean(_ value: Bool) -> Value
  func makeNull() -> Value
  func makeUndefined() -> Value
  func makeObject() -> Value
  func makeArray() -> Value
  func makePropertyStringKey(_ value: String) -> PropertyStringKey

  /// Create a function value with the engine's surface callback signature.
  /// Its creation reference is adopted by the context default scope.
  func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) -> Value

  // MARK: - Global object

  func globalObjectValue() -> Value
  func getGlobalProperty(forKey key: StaticString) -> Value
  func setGlobalProperty(
    _ value: borrowing Value,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  )
  func deleteGlobalProperty(forKey key: StaticString)
  func hasGlobalProperty(_ key: StaticString) -> Bool

  // MARK: - Self-owning inputs and scripts

  func prepareScript(_ source: String) -> PreparedScript
  func evaluateScript(
    _ script: borrowing PreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<Value>
  func evaluateScript(
    _ script: String,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<Value>

  // MARK: - Context data

  func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type)
  func data<K: JSContextDataKey>(for key: K.Type) -> K.Value?
}

extension JSContext {
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing Value) -> R
  ) -> R {
    body(globalObjectValue())
  }

  public func makeNumber(_ value: some BinaryInteger) -> Value {
    makeNumber(Double(value))
  }

  /// Evaluate `script` through a prepared-script handle, the same path the
  /// prepared-script overload takes.
  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<Value> {
    evaluateScript(
      prepareScript(script),
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }
}

extension JSContext {
  /// Install a named function as a global property.
  public func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes = .none,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) {
    let function = makeFunction(named: name, callback: callback)
    guard
      let keyHandle = driverContextHandle.makePropertyStringKeyHandle(name),
      let global = driverContextHandle.globalObjectValueHandle()
    else { return }
    defer { _ = keyHandle.releaseReference() }
    _ = driverContextHandle.setPropertyStringKeyHandle(
      keyHandle,
      on: global,
      to: function.borrowHandle(),
      attributes: attributes
    )
  }
}

// MARK: - Defaults built on the context's own ledger primitives
//
// A concrete context keeps only the engine-specific steps: the ledger
// primitives, the key/script wrappers and the persistent bindings. Everything
// below is derived from `adoptCreatedHandle` and the context handle's driver
// operations.

extension JSContext {
  // MARK: Value factories

  public func makeString(_ value: String) -> Value {
    guard let handle = driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeString(from key: borrowing PropertyStringKey) -> Value {
    guard
      let handle = driverContextHandle.makeStringValueHandle(
        fromPropertyStringKey: key.borrowHandle(in: driverContextHandle)
      )
    else {
      preconditionFailure("makeStringValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNumber(_ value: Double) -> Value {
    guard let handle = driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumberValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeBoolean(_ value: Bool) -> Value {
    guard let handle = driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBooleanValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeNull() -> Value {
    guard let handle = driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNullValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeUndefined() -> Value {
    guard let handle = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefinedValueHandle failed")
    }
    return adoptCreatedHandle(handle)
  }

  public func makeObject() -> Value {
    guard let result = driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObjectResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("JSContext.makeObject failed")
    }
  }

  public func makeArray() -> Value {
    guard let result = driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArrayResultHandle failed")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(handle)
    case .exception:
      preconditionFailure("JSContext.makeArray failed")
    }
  }

  /// The creation reference is adopted by the context default scope, so the
  /// function outlives any single window.
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) -> Value {
    guard
      let handle = driverContextHandle.makeFunctionValueHandle(named: name, callback: callback)
    else {
      preconditionFailure("makeFunctionValueHandle could not create handle")
    }
    return adoptCreatedHandle(handle)
  }

  // MARK: Global object

  /// Read a global property. A failed read is reported as `undefined`: the
  /// engine's exception reference is settled instead of being dropped.
  public func getGlobalProperty(forKey key: StaticString) -> Value {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSContext.getGlobalProperty could not get global object")
    }
    guard
      let result = driverContextHandle.getStaticStringPropertyHandle(key, on: global)
    else {
      preconditionFailure("JSContext.getGlobalProperty returned nil")
    }
    switch consume result {
    case .value(let handle):
      return adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle))
    case .exception(let handle):
      driverContextHandle.releaseCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle))
      guard let undefined = driverContextHandle.makeUndefinedValueHandle() else {
        preconditionFailure("JSContext could not create an undefined handle")
      }
      return adoptCreatedHandle(undefined)
    }
  }

  public func setGlobalProperty(
    _ value: borrowing Value,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes = .none
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

  // MARK: Scripts

  public func evaluateScript(
    _ script: borrowing PreparedScript,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<Value> {
    guard
      let result = driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    else {
      preconditionFailure("JSContext.evaluateScript unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle)))
    case .exception(let handle):
      return .exception(adoptCreatedHandle(ContextHandle.OwnedValueHandle.adopting(handle)))
    }
  }

  // MARK: Context data

  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type = K.self) {
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type = K.self) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }
}
