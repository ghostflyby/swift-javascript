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

  func globalObjectValue() -> Value
  func getGlobalProperty(forKey key: StaticString) -> Value
  func setGlobalProperty(
    _ value: borrowing Value,
    forKey key: StaticString,
    with attributes: JSHostMemberAttributes
  )
  func deleteGlobalProperty(forKey key: StaticString)
  func hasGlobalProperty(_ key: StaticString) -> Bool
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

  /// Mint a persistent binding from a value created in this scope.
  @available(*, noasync)
  func makePersistentHandle(
    _ value: borrowing CallbackValue
  ) -> PersistentHandle

  /// Mint a persistent binding from a value already owned by an arena.
  @available(*, noasync)
  func makePersistentHandle(
    _ value: borrowing Value
  ) -> PersistentHandle

  /// Resolve a handle into a local view anchored on this scope's arena.
  @available(*, noasync)
  func resolve(_ handle: PersistentHandle) -> Value?

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
