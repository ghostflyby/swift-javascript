import SwiftJavaScript

// MARK: - Simple value initializers (S7)
//
// A simple initializer creates its value on the window's arena, then
// `persist`s it so the returned view survives the window.

extension JSCValue {
  public init(string value: String, in context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeString(value), in: context)
  }

  public init(
    string key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) {
    self.init(persisting: context.makeString(from: key), in: context)
  }

  public init(number value: Double, in context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeNumber(value), in: context)
  }

  public init(number value: some BinaryInteger, in context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeNumber(value), in: context)
  }

  public init(boolean value: Bool, in context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeBoolean(value), in: context)
  }

  public init(symbol: String, in context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeSymbol(symbol), in: context)
  }

  public init(nullIn context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeNull(), in: context)
  }

  public init(undefinedIn context: borrowing JSCInstantContext) {
    self.init(persisting: context.makeUndefined(), in: context)
  }

  public init(objectIn context: borrowing JSCInstantContext) {
    guard case .value(let object) = context.makeObject() else {
      preconditionFailure("makeObject failed")
    }
    self.init(persisting: object, in: context)
  }

  public init(arrayIn context: borrowing JSCInstantContext) {
    guard case .value(let array) = context.makeArray() else {
      preconditionFailure("makeArray failed")
    }
    self.init(persisting: array, in: context)
  }

  private init(
    persisting value: borrowing JSCCallbackValue, in context: borrowing JSCInstantContext
  ) {
    let persisted = context.persist(value)
    self.init(
      handle: persisted.borrowHandle(),
      contextHandle: persisted.contextHandle
    )
  }
}
