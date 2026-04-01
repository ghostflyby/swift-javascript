extension JSValue {
  public func type(in context: borrowing JSContext) -> JSType {
    JavaScriptCoreBackendDriver.valueType(of: ref, in: context.globalContextRef)
  }

  public func type(in context: borrowing JSInstantContext) -> JSType {
    JavaScriptCoreBackendDriver.valueType(of: ref, in: context.globalContextRef)
  }

  public func isUndefined(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isUndefined(ref, in: context.globalContextRef)
  }

  public func isUndefined(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isUndefined(ref, in: context.globalContextRef)
  }

  public func isNull(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isNull(ref, in: context.globalContextRef)
  }

  public func isNull(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isNull(ref, in: context.globalContextRef)
  }

  public func isBoolean(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isBoolean(ref, in: context.globalContextRef)
  }

  public func isBoolean(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isBoolean(ref, in: context.globalContextRef)
  }

  public func isNumber(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isNumber(ref, in: context.globalContextRef)
  }

  public func isNumber(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isNumber(ref, in: context.globalContextRef)
  }

  public func isString(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isString(ref, in: context.globalContextRef)
  }

  public func isString(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isString(ref, in: context.globalContextRef)
  }

  public func isSymbol(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isSymbol(ref, in: context.globalContextRef)
  }

  public func isSymbol(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isSymbol(ref, in: context.globalContextRef)
  }

  public func isObject(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isObject(ref, in: context.globalContextRef)
  }

  public func isObject(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isObject(ref, in: context.globalContextRef)
  }

  public func isBigInt(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isBigInt(ref, in: context.globalContextRef)
  }

  public func isBigInt(in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isBigInt(ref, in: context.globalContextRef)
  }
}
