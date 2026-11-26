/// A callback-scoped value view.
///
/// Structurally the same non-owning `handle + context` pair as `JSValue`, but
/// with the callback contract: the value is only valid inside the synchronous
/// scope window (or the engine argument frame) whose arena backs the handle,
/// and it is constructed exclusively by the scope that owns that window.
///
/// The concrete type is the engine's own callback wrapper (`JSCValue`'s
/// callback counterpart, `QJSCallbackValue`).
public protocol JSCallbackValue: ~Copyable {
  /// The context this view belongs to.
  associatedtype Context: JSContext

  /// The engine's classification of this value (`JSValueGetType`/`JS_TypeOfValue`).
  func type() -> JSType

  /// Convert the value to a string (engine `ToString`).
  func toString() -> String

  /// Convert the value to a number (engine `ToNumber`).
  func toNumber() -> Double

  /// Convert the value to a boolean (engine `ToBoolean`).
  func toBoolean() -> Bool

  func isUndefined() -> Bool
  func isNull() -> Bool
  func isBoolean() -> Bool
  func isNumber() -> Bool
  func isString() -> Bool
  func isSymbol() -> Bool
  func isObject() -> Bool
  func isBigInt() -> Bool

  /// `==` in JavaScript (engine `IsEqual`).
  func looselyEquals(_ other: borrowing Self) -> Bool

  /// `===` in JavaScript (engine `IsStrictEqual`).
  func strictlyEquals(_ other: borrowing Self) -> Bool

  /// Pack this callback-window value into a single call-argument token.
  ///
  /// The value factories (`makeNumber`/`makeString`) return this type, not the
  /// owned `Value`, so the callback window needs its own token entry point.
  /// The token borrows this value's engine handle and is valid only for the
  /// immediate synchronous call it is passed to.
  func asCallArgument() -> Context.CallArgument
}

// The callback window's eight predicates derive from `type()`, exactly like
// `JSValue`'s. Conversion and equality are requirements: the engine's callback
// value implements them directly against its own context driver and keeps the
// `noasync` callback-window contract on the concrete type.
extension JSCallbackValue where Self: ~Copyable {
  @available(*, noasync)
  public func isUndefined() -> Bool { type() == .undefined }
  @available(*, noasync)
  public func isNull() -> Bool { type() == .null }
  @available(*, noasync)
  public func isBoolean() -> Bool { type() == .boolean }
  @available(*, noasync)
  public func isNumber() -> Bool { type() == .number }
  @available(*, noasync)
  public func isString() -> Bool { type() == .string }
  @available(*, noasync)
  public func isSymbol() -> Bool { type() == .symbol }
  @available(*, noasync)
  public func isObject() -> Bool { type() == .object }
  @available(*, noasync)
  public func isBigInt() -> Bool { type() == .bigInt }
}
