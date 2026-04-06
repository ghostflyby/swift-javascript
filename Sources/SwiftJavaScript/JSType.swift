public enum JSType: Sendable {
  case undefined
  case null
  case boolean
  case number
  case string
  case symbol
  case object
  case bigInt
}

extension JSValue {
  public func type(in context: borrowing JSContext<E>) -> JSType {
    let instantContext = JSInstantContext<E>(handle: context.driverContextHandle)
    return type(in: instantContext)
  }

  public func type(in context: borrowing JSInstantContext<E>) -> JSType {
    guard let valueType = E.valueTypeForHandle(_rawValue, in: context.driverContextHandle)
    else {
      preconditionFailure("JSValue.type(in:) could not query value type")
    }
    return valueType
  }

  public func isUndefined(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .undefined
  }

  public func isUndefined(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .undefined
  }

  public func isNull(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .null
  }

  public func isNull(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .null
  }

  public func isBoolean(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .boolean
  }

  public func isBoolean(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .boolean
  }

  public func isNumber(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .number
  }

  public func isNumber(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .number
  }

  public func isString(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .string
  }

  public func isString(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .string
  }

  public func isSymbol(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .symbol
  }

  public func isSymbol(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .symbol
  }

  public func isObject(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .object
  }

  public func isObject(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .object
  }

  public func isBigInt(in context: borrowing JSContext<E>) -> Bool {
    type(in: context) == .bigInt
  }

  public func isBigInt(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .bigInt
  }
}
