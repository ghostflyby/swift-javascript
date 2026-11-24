import SwiftJavaScript

// MARK: - Simple value initializers (S7)
//
// QuickJS counterpart of the JavaScriptCore file: create on the window's
// arena, then `persist` so the returned view survives the window.

extension QJSValue {
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
    persisting value: borrowing QJSCallbackValue, in context: borrowing QJSInstantContext
  ) {
    let persisted = context.persist(value)
    self.init(
      handle: persisted.borrowHandle(),
      contextHandle: persisted.contextHandle
    )
  }
}
