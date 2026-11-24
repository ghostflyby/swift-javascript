/// The user-facing local value view (design §3.2), expressed as a protocol.
///
/// The concrete type is the engine's own value wrapper (`JSCValue`,
/// `QJSValue`); core keeps only the identity contract shared code needs: the
/// context it belongs to, the context identity the view is addressed through,
/// and the borrowed value-handle token.
///
/// A `JSValue` owns nothing. The engine reference is owned by the scope arena
/// the value was created in or promoted to, so copying a view is a pure
/// identity copy and dropping it performs no release.
///
/// The protocol names only what a value needs — the context it belongs to and
/// its two handle tokens and scope, each an alias of the context's. A value's
/// operations return the context's value type.
public protocol JSValue: ~Copyable {
  /// The context this value belongs to.
  associatedtype Context: JSContext
  /// The context identity this view is addressed through. Its driver also
  /// classifies, converts and compares values.
  associatedtype ContextHandle: JSContextRuntimeDriver & JSContextInvocationDriver
  where ContextHandle == Context.ContextHandle
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
  where ValueHandle == Context.ValueHandle
  /// The synchronous scope this value is addressed in.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

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

  // MARK: - Property access (S5)

  func getProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func getProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
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

  /// Call the value as a function. Arguments are passed as borrowed handles;
  /// the caller keeps their arenas alive across the synchronous call.
  func call(
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func call(
    this thisValue: borrowing Self,
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func construct(
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func invokeMethod(
    _ name: StaticString,
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value>

  func invokeMethod(
    _ name: borrowing InstantContext.PropertyStringKey,
    arguments: [ValueHandle],
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

// Every base operation except `type()` has a default that routes through the
// view's context driver. The predicates are expressed in terms of `type()`, so
// an engine that classifies values correctly gets all eight for free.
extension JSValue where Self: ~Copyable {
  public func toString() -> String {
    contextHandle.toStringForHandle(borrowHandle()) ?? ""
  }

  public func toNumber() -> Double {
    contextHandle.toNumberForHandle(borrowHandle())
  }

  public func toBoolean() -> Bool {
    contextHandle.toBooleanForHandle(borrowHandle())
  }

  public func isUndefined() -> Bool { type() == .undefined }
  public func isNull() -> Bool { type() == .null }
  public func isBoolean() -> Bool { type() == .boolean }
  public func isNumber() -> Bool { type() == .number }
  public func isString() -> Bool { type() == .string }
  public func isSymbol() -> Bool { type() == .symbol }
  public func isObject() -> Bool { type() == .object }
  public func isBigInt() -> Bool { type() == .bigInt }

  public func looselyEquals(_ other: borrowing Self) -> Bool {
    contextHandle.looselyEqualsHandle(borrowHandle(), other.borrowHandle()) ?? false
  }

  public func strictlyEquals(_ other: borrowing Self) -> Bool {
    contextHandle.strictlyEqualsHandle(borrowHandle(), other.borrowHandle()) ?? false
  }
}
