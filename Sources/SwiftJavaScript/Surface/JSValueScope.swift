/// The value-factory face shared by both surface scopes.
///
/// `JSInstantContext` (a callback window) and `JSScope` (a manual window) both
/// create values on their own arena, promote values to the context default
/// scope, and expose the engine's local views. The conversion protocols
/// (`JSValueEncodable`, `JSValueEncoder`) and the shared
/// defaults are written against this face so neither scope kind has to be
/// special-cased.
public protocol JSValueScope: ~Copyable {
  /// The context this scope belongs to.
  associatedtype Context: JSContext
  associatedtype Value: JSValue & ~Copyable
  where Value == Context.Value
  associatedtype CallbackValue: JSCallbackValue & ~Copyable
  where CallbackValue == Context.CallbackValue
  associatedtype PropertyStringKey: JSPropertyStringKey & ~Copyable
  where PropertyStringKey == Context.PropertyStringKey

  // MARK: Value factories

  func makeString(_ value: String) -> CallbackValue
  func makeString(from key: borrowing PropertyStringKey) -> CallbackValue
  func makeNumber(_ value: Double) -> CallbackValue
  func makeBoolean(_ value: Bool) -> CallbackValue
  func makeNull() -> CallbackValue
  func makeUndefined() -> CallbackValue
  func makeSymbol(_ value: String) -> CallbackValue
  func makeObject() -> JSResult<CallbackValue>
  func makeArray() -> JSResult<CallbackValue>

  // MARK: Persistence

  /// Transfer the value's owned reference into the context default scope and
  /// return a view valid beyond this window.
  func persist(_ value: borrowing CallbackValue) -> Value

  /// The local value view of a value that is already backed by this window's
  /// arena (a callback argument, or a value this scope's factories produced):
  /// no claim, no ledger entry. The view is only valid while the source arena
  /// is alive, so it is confined to the synchronous window that produced it;
  /// the macro templates hand `CallbackValue`s to `JSValueDecodable` through
  /// it, and core's `setGlobalProperty(CallbackValue:…)` convenience uses it
  /// too.
  @available(*, noasync)
  func localValue(_ value: borrowing CallbackValue) -> Value

  // MARK: Value window

  /// Run `body` in a synchronous value-operation window on this scope's arena.
  ///
  /// `JSInstantContext` returns itself; a manual `JSScope` opens a nested
  /// synchronous window whose arena drains when `body` returns. This is the
  /// only channel through which generic scope code reaches value operations:
  /// the repository deliberately does not pin `Context.InstantContext == Self`
  /// (doing so makes type checking fail to terminate, see TODO §3.16).
  ///
  /// **Hard constraint**: values produced by window arithmetic are only valid
  /// inside `body` and must not escape it. For a `JSInstantContext` the window
  /// is the caller itself — the same arena, valid for as long as the caller
  /// lives. For a `JSScope` the window drains when `body` returns, so any
  /// `Value` adopted inside the closure is only valid there. A `CallbackValue`
  /// that must outlive the window has to be `persist`ed to the context default
  /// scope first; a `Value` (for example the adopted result of `getProperty`)
  /// has no persist channel, so it must be used inside the closure or moved
  /// into an independent binding via `makePersistentHandle(_ value: borrowing
  /// Value)`.
  func withInstantWindow<R: ~Copyable, Failure: Error>(
    _ body: (borrowing Context.InstantContext) throws(Failure) -> R
  ) throws(Failure) -> R

  // MARK: Self-owning inputs

  func makePropertyStringKey(_ value: String) -> PropertyStringKey
}

extension JSValueScope where Self: ~Copyable {
  public func makeNumber(_ value: some BinaryInteger) -> CallbackValue {
    makeNumber(Double(value))
  }
}
