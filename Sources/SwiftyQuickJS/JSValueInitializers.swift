import SwiftJavaScript

// MARK: - Simple value initializers (S7)
//
// QuickJS counterpart of the JavaScriptCore file: create on the window's
// arena, then `persist` so the returned view survives the window.

extension QJSValue {
  // MARK: Context-free immediate values
  //
  // These values are encoded entirely in the tagged value: QuickJS allocates
  // nothing and touches no runtime, so no context is involved. They can be
  // passed to any operation that takes an explicit context and can be minted
  // as persistent bindings through any hosted context.
  //
  // `QJSValue` is `~Copyable`, while the stdlib literal protocols inherit
  // `Copyable`, so the value type cannot conform to `ExpressibleBy*`; these
  // initializers are the literal-construction path that keeps the
  // non-copyable value contract.

  /// The `undefined` value.
  public static var undefined: QJSValue {
    QJSValue(value: quickJSMakeUndefined(), contextRef: nil)
  }

  /// The `null` value.
  public static var null: QJSValue {
    QJSValue(value: quickJSMakeNull(), contextRef: nil)
  }

  public init(boolean value: Bool) {
    self.init(value: quickJSMakeBoolean(value), contextRef: nil)
  }

  public init(number value: Double) {
    self.init(value: quickJSMakeNumber(value), contextRef: nil)
  }

  public init(number value: some BinaryInteger) {
    self.init(value: quickJSMakeNumber(value), contextRef: nil)
  }

  public init(string value: String, in context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeString(value), in: context)
  }

  public init(
    string key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) {
    self.init(persisting: context.makeString(from: key), in: context)
  }

  public init(number value: Double, in context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeNumber(value), in: context)
  }

  public init(number value: some BinaryInteger, in context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeNumber(value), in: context)
  }

  public init(boolean value: Bool, in context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeBoolean(value), in: context)
  }

  public init(symbol: String, in context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeSymbol(symbol), in: context)
  }

  public init(nullIn context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeNull(), in: context)
  }

  public init(undefinedIn context: borrowing QJSInstantContext) {
    self.init(persisting: context.makeUndefined(), in: context)
  }

  public init(objectIn context: borrowing QJSInstantContext) {
    guard case .value(let object) = context.makeObject() else {
      preconditionFailure("makeObject failed")
    }
    self.init(persisting: object, in: context)
  }

  public init(arrayIn context: borrowing QJSInstantContext) {
    guard case .value(let array) = context.makeArray() else {
      preconditionFailure("makeArray failed")
    }
    self.init(persisting: array, in: context)
  }

  private init(
    persisting value: borrowing QJSValue, in context: borrowing QJSInstantContext
  ) {
    let persisted = context.persist(value)
    self.init(
      value: persisted.value,
      contextRef: persisted.contextRef
    )
  }
}
