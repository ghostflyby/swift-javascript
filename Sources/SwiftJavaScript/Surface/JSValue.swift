/// The user-facing local value view (design §3.2), expressed as a protocol.
///
/// The concrete type is the engine's own value wrapper (`JSCValue`,
/// `QJSValue`); core keeps only the identity contract shared code needs: the
/// context it belongs to and the synchronous scope it is addressed in.
///
/// A `JSValue` owns nothing. The engine reference is owned by the scope arena
/// the value was created in or promoted to, so copying a view is a pure
/// identity copy and dropping it performs no release.
///
/// The protocol names only what a value needs — the context it belongs to and
/// its scope, each an alias of the context's. A value's operations return the
/// context's value type.
public protocol JSValue: ~Copyable {
  /// The context this value belongs to.
  associatedtype Context: JSContext
  /// The synchronous scope this value is addressed in.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

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

  /// Pack this value into a single call-argument token.
  ///
  /// The token borrows this value's engine handle; it is valid only while this
  /// value's arena is alive and only for the immediate synchronous call it is
  /// passed to.
  func asCallArgument() -> Context.CallArgument

  // MARK: - Property access (S5)

  func getProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func getProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  /// Read the element at `index` (engine `getIndexPropertyHandle`).
  func getProperty(
    at index: Int,
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func setProperty(
    _ key: StaticString,
    to value: borrowing Self,
    attributes: JSHostMemberAttributes,
    in context: borrowing InstantContext
  ) -> Bool

  func setProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    to value: borrowing Self,
    attributes: JSHostMemberAttributes,
    in context: borrowing InstantContext
  ) -> Bool

  /// Write the element at `index` (engine `setIndexPropertyHandle`).
  func setProperty(
    at index: Int,
    to value: borrowing Self,
    in context: borrowing InstantContext
  ) -> Bool

  func deleteProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> Bool

  func deleteProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> Bool

  func hasProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> Bool

  func hasProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> Bool

  /// The object's own enumerable string-keyed property names (engine
  /// `propertyNamesForHandle`; an engine failure reads as no names).
  func propertyNames(in context: borrowing InstantContext) -> [String]

  // MARK: - Invocation (S5)

  /// Call the value as a function. Arguments are value-level tokens
  /// (`asCallArgument()`); the caller keeps their source arenas alive across
  /// the synchronous call.
  func call(
    arguments: [Context.CallArgument],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func call(
    this thisValue: borrowing Self,
    arguments: [Context.CallArgument],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func construct(
    arguments: [Context.CallArgument],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func invokeMethod(
    _ name: StaticString,
    arguments: [Context.CallArgument],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func invokeMethod(
    _ name: borrowing InstantContext.PropertyStringKey,
    arguments: [Context.CallArgument],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func toObject(in context: borrowing InstantContext) -> JSResult<Context.Value>

  func isArray(in context: borrowing InstantContext) -> Bool

  func isDate(in context: borrowing InstantContext) -> Bool

  func isInstanceOf(
    _ constructor: borrowing Self,
    in context: borrowing InstantContext
  ) -> Bool

  func isArrayBuffer(in context: borrowing InstantContext) -> Bool

  func isTypedArray(in context: borrowing InstantContext) -> Bool
}

// The predicates are expressed in terms of `type()`, so an engine that
// classifies values correctly gets all eight for free. Every other operation
// is implemented by the engine's value type against its own context driver.
extension JSValue where Self: ~Copyable {
  public func isUndefined() -> Bool { type() == .undefined }
  public func isNull() -> Bool { type() == .null }
  public func isBoolean() -> Bool { type() == .boolean }
  public func isNumber() -> Bool { type() == .number }
  public func isString() -> Bool { type() == .string }
  public func isSymbol() -> Bool { type() == .symbol }
  public func isObject() -> Bool { type() == .object }
  public func isBigInt() -> Bool { type() == .bigInt }
}
