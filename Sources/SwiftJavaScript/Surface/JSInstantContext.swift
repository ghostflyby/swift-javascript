/// A synchronous scope window.
///
/// The concrete type owns the scope arena that backs the values created in the
/// window (`JSCInstantContext`, `QJSInstantContext`); core shares the
/// arena/scope-stack algorithm. Values are released when the scope exits
/// unless they were promoted to the context default scope.
///
/// Generic code that operates on the window's values takes the context as its
/// root (`C.InstantContext`), not a bare window type: the operations of
/// `Value` are addressed in `Value.InstantContext`, which a generic
/// `JSInstantContext` can only show to be its *context's* window type. See
/// `JSContext` for why the window does not pin itself to its context.
public protocol JSInstantContext: JSValueScope, ~Copyable {
  associatedtype CallbackReturn: JSCallbackReturn & ~Copyable
  where CallbackReturn == Context.CallbackReturn
  /// The callback-window argument view and the plain argument view.
  associatedtype CallbackArguments: JSCallbackArguments & ~Copyable
  where CallbackArguments == Context.CallbackArguments
  associatedtype Arguments: JSArguments & ~Copyable
  where Arguments == Context.Arguments
  associatedtype PreparedScript: JSPreparedScript & ~Copyable
  where PreparedScript == Context.PreparedScript
  associatedtype PersistentHandle: JSPersistentHandle
  where PersistentHandle == Context.PersistentHandle

  // MARK: - Callback exit

  /// Return an arena-owned value.
  func `return`(_ value: borrowing Value) -> CallbackReturn

  /// Throw an arena-owned value.
  func `throw`(_ value: borrowing Value) -> CallbackReturn

  func returnUndefined() -> CallbackReturn
  func throwUndefined() -> CallbackReturn

  // MARK: - Global object

  /// The context's global object as a local view. Global-object handles are
  /// borrowed from the engine, so the view needs no arena entry.
  func globalObjectValue() -> Value

  /// Read a global property. A failed read is reported as `undefined`, the
  /// same mapping the legacy scope uses.
  func getGlobalProperty(forKey key: StaticString) -> Value

  func setGlobalProperty(
    _ value: borrowing Value,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  )

  func deleteGlobalProperty(forKey key: StaticString)

  func hasGlobalProperty(_ key: StaticString) -> Bool

  /// Create a function value using the engine's surface callback signature.
  /// The function outlives this window (it is normally stored as a property),
  /// so its creation reference is adopted by the context default scope.
  func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<Self>
  ) -> Value

  func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes,
    callback: @escaping JSFunctionCallback<Self>
  )

  // MARK: - Persistent bindings

  /// Mint a persistent binding for a value created in this window. Requires a
  /// hosted `JSContext`: the registry is reached through the context data box.
  @available(*, noasync)
  func makePersistentHandle(
    _ value: borrowing Value
  ) -> PersistentHandle

  /// Resolve a handle into a local view anchored on this window's arena.
  @available(*, noasync)
  func resolve(_ handle: PersistentHandle) -> Value?

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

// MARK: - Value-level composition
//
// These defaults only combine value-level requirements: no handle, no adopt.
// What each engine implements itself is exactly the operations that create and
// adopt a new value (factories, global reads, script results, data access,
// function/key/script construction), because the target arena of the adoption
// belongs to the engine.

extension JSInstantContext where Self: ~Copyable {
  /// Write a value by name with the default attributes.
  public func setGlobalProperty(_ value: borrowing Value, forKey key: StaticString) {
    setGlobalProperty(value, forKey: key, with: .none)
  }

  /// Install a named function as a global property.
  public func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes,
    callback: @escaping JSFunctionCallback<Self>
  ) {
    let function = makeFunction(named: name, callback: callback)
    let key = makePropertyStringKey(name)
    withInstantWindow { window throws(Never) in
      let global = window.globalObjectValue()
      _ = global.setProperty(key, to: function, attributes: attributes, in: window)
    }
  }

  /// Install a named function as a global property with the default attributes.
  public func installGlobalFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<Self>
  ) {
    installGlobalFunction(named: name, with: .none, callback: callback)
  }

  /// Evaluate `script` through a prepared script wrapped in this window.
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
