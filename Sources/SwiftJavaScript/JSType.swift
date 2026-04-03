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

extension JSEngineValue {
  public func type(in context: borrowing JSEngineContext<E>) -> JSType {
    let instantContext = JSEngineInstantContext<E>(handle: context.driverContextHandle)
    return type(in: instantContext)
  }

  public func type(in context: borrowing JSEngineInstantContext<E>) -> JSType {
    guard let valueType = E.valueTypeForHandle(_rawValue.valueHandle(), in: context.driverContextHandle)
    else {
      preconditionFailure("JSEngineValue.type(in:) could not query value type")
    }
    return valueType
  }

  public func isUndefined(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .undefined
  }

  public func isUndefined(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .undefined
  }

  public func isNull(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .null
  }

  public func isNull(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .null
  }

  public func isBoolean(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .boolean
  }

  public func isBoolean(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .boolean
  }

  public func isNumber(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .number
  }

  public func isNumber(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .number
  }

  public func isString(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .string
  }

  public func isString(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .string
  }

  public func isSymbol(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .symbol
  }

  public func isSymbol(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .symbol
  }

  public func isObject(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .object
  }

  public func isObject(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .object
  }

  public func isBigInt(in context: borrowing JSEngineContext<E>) -> Bool {
    type(in: context) == .bigInt
  }

  public func isBigInt(in context: borrowing JSEngineInstantContext<E>) -> Bool {
    type(in: context) == .bigInt
  }
}
