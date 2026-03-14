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
  public var type: JSType {
    JavaScriptCoreBackendDriver.valueType(of: ref, in: ctx)
  }
}

extension JSValue {
  public var isUndefined: Bool {
    JavaScriptCoreBackendDriver.isUndefined(ref, in: ctx)
  }

  public var isNull: Bool {
    JavaScriptCoreBackendDriver.isNull(ref, in: ctx)
  }

  public var isBoolean: Bool {
    JavaScriptCoreBackendDriver.isBoolean(ref, in: ctx)
  }

  public var isNumber: Bool {
    JavaScriptCoreBackendDriver.isNumber(ref, in: ctx)
  }

  public var isString: Bool {
    JavaScriptCoreBackendDriver.isString(ref, in: ctx)
  }

  public var isSymbol: Bool {
    JavaScriptCoreBackendDriver.isSymbol(ref, in: ctx)
  }

  public var isObject: Bool {
    JavaScriptCoreBackendDriver.isObject(ref, in: ctx)
  }

  public var isBigInt: Bool {
    JavaScriptCoreBackendDriver.isBigInt(ref, in: ctx)
  }
}
