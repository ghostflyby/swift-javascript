/// A manual scope with explicit open/close.
///
/// Like `JSInstantContext`, but the caller decides when the window is open;
/// callback-exit semantics (`return`/`throw`) are not part of this surface.
/// The concrete type is `~Sendable` so the scope cannot leave the isolation
/// whose VM thread its arena drains on.
public protocol JSScope: JSValueScope, ~Copyable {
  /// The synchronous callback-window type of this engine. Functions created in
  /// this scope run their callback in that window type.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext
  associatedtype PreparedScript: JSPreparedScript & ~Copyable
  where PreparedScript == Context.PreparedScript
  associatedtype PersistentHandle: JSPersistentHandle
  where PersistentHandle == Context.PersistentHandle

  // MARK: - Global object

  @_lifetime(borrow self)
  func globalObjectValue() -> Value
  @_lifetime(borrow self)
  func getGlobalProperty(forKey key: StaticString) -> Value
  func setGlobalProperty(
    _ value: borrowing Value,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  )
  func deleteGlobalProperty(forKey key: StaticString)
  func hasGlobalProperty(_ key: StaticString) -> Bool
  @_lifetime(borrow self)
  func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<InstantContext>
  ) -> Value
  func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes,
    callback: @escaping JSFunctionCallback<InstantContext>
  )

  // MARK: - Persistent bindings

  /// Mint a persistent binding from a value created in this scope, or from a
  /// context-free immediate value.
  @available(*, noasync)
  func makePersistentHandle(
    _ value: borrowing Value
  ) -> PersistentHandle

  /// Resolve a handle into a local view anchored on this scope's arena.
  @available(*, noasync)
  @_lifetime(borrow self)
  func resolve(_ handle: PersistentHandle) -> Value?

  // MARK: - Self-owning inputs and scripts

  func prepareScript(_ source: String) -> PreparedScript
  @_lifetime(borrow self)
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

extension JSScope where Self: ~Copyable {
  /// Write a value by name with the default attributes.
  public func setGlobalProperty(_ value: borrowing Value, forKey key: StaticString) {
    setGlobalProperty(value, forKey: key, with: .none)
  }

  /// Install a named function as a global property.
  public func installGlobalFunction(
    named name: String,
    with attributes: JSHostMemberAttributes,
    callback: @escaping JSFunctionCallback<InstantContext>
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
    callback: @escaping JSFunctionCallback<InstantContext>
  ) {
    installGlobalFunction(named: name, with: .none, callback: callback)
  }

  /// Evaluate `script` through a prepared script wrapped in this scope.
  @_lifetime(borrow self)
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
