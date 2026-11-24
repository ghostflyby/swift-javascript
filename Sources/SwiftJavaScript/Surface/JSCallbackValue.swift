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
  /// The context identity this view is addressed through. Its driver also
  /// classifies, converts and compares values.
  associatedtype ContextHandle: JSContextRuntimeDriver & JSContextInvocationDriver
  where ContextHandle == Context.ContextHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle == Context.ValueHandle

  /// The borrowed engine handle token backing this view.
  borrowing func borrowHandle() -> ValueHandle

  /// The context identity this view is addressed through.
  var contextHandle: ContextHandle { get }

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
}

// The callback window's conversion/equality operations route through the same
// context driver as `JSValue`; only `type()` is left to the concrete type,
// because it is the one operation whose engine shape differs. All of them are
// `noasync`, preserving the callback-window contract: these views only
// exist inside a synchronous callback window.
extension JSCallbackValue where Self: ~Copyable {
  @available(*, noasync)
  public func toString() -> String {
    contextHandle.toStringForHandle(borrowHandle()) ?? ""
  }

  @available(*, noasync)
  public func toNumber() -> Double {
    contextHandle.toNumberForHandle(borrowHandle())
  }

  @available(*, noasync)
  public func toBoolean() -> Bool {
    contextHandle.toBooleanForHandle(borrowHandle())
  }

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

  @available(*, noasync)
  public func looselyEquals(_ other: borrowing Self) -> Bool {
    contextHandle.looselyEqualsHandle(borrowHandle(), other.borrowHandle()) ?? false
  }

  @available(*, noasync)
  public func strictlyEquals(_ other: borrowing Self) -> Bool {
    contextHandle.strictlyEqualsHandle(borrowHandle(), other.borrowHandle()) ?? false
  }
}
