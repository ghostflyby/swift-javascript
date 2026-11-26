/// The engine context actor.
///
/// The concrete type is the engine's context (`JSCContext`, `QJSContext`);
/// each engine keeps the shared default-scope/registry/data-box lifecycle in
/// its own `JSContextStorage`. The context-level factories, global
/// access, script evaluation, and data storage are engine requirements: each
/// one creates or settles engine references on the context default scope, so
/// only the concrete actor can implement it. Core keeps the value-level
/// composition that never creates a reference (the installed-function
/// wrapper, the numeric and global-object conveniences, the string-script
/// overload).
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
  associatedtype VirtualMachine: JSVirtualMachine
  where VirtualMachine.Context == Self
  associatedtype Value: JSValue & ~Copyable
  where
    Value.Context == Self,
    Value.InstantContext == InstantContext
  associatedtype CallbackValue: JSCallbackValue & ~Copyable
  where CallbackValue.Context == Self
  associatedtype CallbackReturn: JSCallbackReturn & ~Copyable
  where CallbackReturn.Context == Self
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
    Scope.InstantContext == InstantContext,
    Scope.Value == Value,
    Scope.CallbackValue == CallbackValue,
    Scope.PropertyStringKey == PropertyStringKey,
    Scope.PreparedScript == PreparedScript,
    Scope.PersistentHandle == PersistentHandle
  associatedtype PersistentHandle: JSPersistentHandle
  associatedtype PropertyStringKey: JSPropertyStringKey & ~Copyable
  where PropertyStringKey.Context == Self
  associatedtype PreparedScript: JSPreparedScript & ~Copyable
  where PreparedScript.Context == Self
  associatedtype ArrayBuffer: JSArrayBuffer & ~Copyable
  where
    ArrayBuffer.Context == Self,
    ArrayBuffer.Value == Value,
    ArrayBuffer.InstantContext == InstantContext
  associatedtype TypedArray: JSTypedArray & ~Copyable
  where
    TypedArray.Context == Self,
    TypedArray.Value == Value,
    TypedArray.InstantContext == InstantContext,
    TypedArray.Buffer == ArrayBuffer
  /// The value-level argument token used by this context's call operations.
  /// Deliberately not tied to `Self`/`Value` here: the token is produced by
  /// `JSValue.asCallArgument()`/`JSCallbackValue.asCallArgument()`, where the
  /// compiler already knows the context; restating the relation makes type
  /// checking diverge.
  associatedtype CallArgument: JSCallArgument
  associatedtype Class: JSClass
  where Class.Context == Self

  /// Create a context on `virtualMachine`, with its own engine context handle,
  /// default scope, and persistent registry.
  init(virtualMachine: VirtualMachine)

  /// The VM that owns the runtime this context runs on. Nonisolated because
  /// it is immutable identity.
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

  /// Install a named function as a global property.
  func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes,
    callback: @escaping JSFunctionCallback<InstantContext>
  )

  // MARK: - Self-owning inputs and scripts

  func prepareScript(_ source: String) -> PreparedScript
  func evaluateScript(
    _ script: borrowing PreparedScript,
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

  /// Write a value by name with the default attributes.
  public func setGlobalProperty(_ value: borrowing Value, forKey key: StaticString) {
    setGlobalProperty(value, forKey: key, with: .none)
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
  ///
  /// Value-level composition: `makeFunction` parks the function's creation
  /// reference on the context default scope, and the write runs in a
  /// synchronous window on the same context. No engine implementation is
  /// needed — the scope kinds share the same recipe.
  public func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) {
    let function = makeFunction(named: name, callback: callback)
    let key = makePropertyStringKey(name)
    withInstantContext { window throws(Never) in
      let global = window.globalObjectValue()
      _ = global.setProperty(key, to: function, attributes: attributes, in: window)
    }
  }

  /// Install a named function as a global property with the default
  /// attributes.
  public func installGlobalFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) {
    installGlobalFunction(named: name, with: .none, callback: callback)
  }
}
