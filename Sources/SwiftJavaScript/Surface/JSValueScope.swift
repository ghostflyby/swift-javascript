/// The value-factory face shared by both surface scopes.
///
/// `JSInstantContext` (a callback window) and `JSScope` (a manual window) both
/// create values on their own arena, promote values to the context default
/// scope, and expose the engine's local views. The conversion protocols
/// (`JSValueEncodable`, `JSValueEncoder`) and the shared
/// defaults are written against this face so neither scope kind has to be
/// special-cased.
/// The context-handle capabilities a synchronous scope needs: value
/// factories, property access, function invocation and prepared scripts.
public typealias JSScopeContextHandle = JSContextRuntimeDriver & JSContextPropertyDriver
  & JSContextInvocationDriver & JSContextPreparedScriptDriver

public protocol JSValueScope: ~Copyable {
  /// The context this scope belongs to.
  associatedtype Context: JSContext
  associatedtype ContextHandle: JSScopeContextHandle
  where ContextHandle == Context.ContextHandle
  associatedtype Value: JSValue & ~Copyable
  where Value == Context.Value
  associatedtype CallbackValue: JSCallbackValue & ~Copyable
  where CallbackValue == Context.CallbackValue
  associatedtype PropertyStringKey: JSPropertyStringKey & ~Copyable
  where PropertyStringKey == Context.PropertyStringKey

  /// The context identity every operation of this window is addressed through.
  var driverContextHandle: ContextHandle { get }

  /// Adopt an engine-created owning handle into this window's arena and
  /// return the local view. The handle is tracked exactly once, so the
  /// window's drain settles the creation reference.
  func adoptCreatedHandle(_ handle: consuming ContextHandle.OwnedValueHandle) -> Value

  /// Adopt an engine-created owning handle into this window's arena and
  /// return the callback-window view of it. Same ledger as
  /// `adoptCreatedHandle`; every value factory below is built on it.
  func adoptCallbackHandle(_ handle: consuming ContextHandle.OwnedValueHandle) -> CallbackValue

  /// Claim an owned reference for a borrowed handle that no arena owns yet,
  /// track it exactly once on this window's arena, and return the local view.
  func anchorBorrowedHandle(_ handle: ContextHandle.ValueHandle) -> Value

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

  // MARK: Self-owning inputs

  func makePropertyStringKey(_ value: String) -> PropertyStringKey
}

extension JSValueScope where Self: ~Copyable {
  public func makeNumber(_ value: some BinaryInteger) -> CallbackValue {
    makeNumber(Double(value))
  }
}
