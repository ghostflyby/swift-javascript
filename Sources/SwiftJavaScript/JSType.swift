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

extension JSValue where E: JSEngineRuntimeDriver {
  public func type(in context: borrowing JSContext<E> = #isolation) -> JSType
  where E: JSContextEngine {
    let instantContext = JSInstantContext<E>(handle: context.driverContextHandle)
    return type(in: instantContext)
  }

  public func type(in context: borrowing JSInstantContext<E>) -> JSType {
    guard let valueType = context.driverContextHandle.valueTypeForHandle(borrowHandle())
    else {
      preconditionFailure("JSValue.type(in:) could not query value type")
    }
    return valueType
  }

  public func isUndefined(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .undefined
  }

  public func isUndefined(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .undefined
  }

  public func isNull(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .null
  }

  public func isNull(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .null
  }

  public func isBoolean(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .boolean
  }

  public func isBoolean(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .boolean
  }

  public func isNumber(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .number
  }

  public func isNumber(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .number
  }

  public func isString(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .string
  }

  public func isString(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .string
  }

  public func isSymbol(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .symbol
  }

  public func isSymbol(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .symbol
  }

  public func isObject(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .object
  }

  public func isObject(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .object
  }

  public func isBigInt(in context: borrowing JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    type(in: context) == .bigInt
  }

  public func isBigInt(in context: borrowing JSInstantContext<E>) -> Bool {
    type(in: context) == .bigInt
  }
}
