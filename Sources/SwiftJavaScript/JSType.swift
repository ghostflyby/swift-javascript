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
  public func type(in context: borrowing isolated JSContext<E> = #isolation) -> JSType {
    let instantContext = JSInstantContext<E>(handle: context.driverContextHandle)
    return type(in: instantContext)
  }

  public func type(in context: borrowing JSInstantContext<E>) -> JSType {
    guard let valueType = E.valueTypeForHandle(borrowHandle(), in: context.driverContextHandle)
    else {
      preconditionFailure("JSValue.type(in:) could not query value type")
    }
    return valueType
  }

  public func isUndefined(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .undefined
  }

  public func isUndefined(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .undefined
  }

  public func isNull(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .null
  }

  public func isNull(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .null
  }

  public func isBoolean(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .boolean
  }

  public func isBoolean(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .boolean
  }

  public func isNumber(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .number
  }

  public func isNumber(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .number
  }

  public func isString(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .string
  }

  public func isString(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .string
  }

  public func isSymbol(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .symbol
  }

  public func isSymbol(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .symbol
  }

  public func isObject(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .object
  }

  public func isObject(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .object
  }

  public func isBigInt(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    let instantContext = JSInstantContext<E>(context: context)
    return type(in: instantContext) == .bigInt
  }

  public func isBigInt(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .bigInt
  }
}
