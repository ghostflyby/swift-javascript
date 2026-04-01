extension JSValue {
  public func type(in context: borrowing JSContext) -> JSType {
    JavaScriptCoreBackendDriver.valueType(of: ref, in: context.globalContextRef)
  }

  public func type(in context: borrowing JSInstantContext) -> JSType {
    context.valueType(of: self)
  }

  public func isUndefined(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isUndefined(ref, in: context.globalContextRef)
  }

  public func isUndefined(in context: borrowing JSInstantContext) -> Bool {
    context.isUndefined(self)
  }

  public func isNull(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isNull(ref, in: context.globalContextRef)
  }

  public func isNull(in context: borrowing JSInstantContext) -> Bool {
    context.isNull(self)
  }

  public func isBoolean(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isBoolean(ref, in: context.globalContextRef)
  }

  public func isBoolean(in context: borrowing JSInstantContext) -> Bool {
    context.isBoolean(self)
  }

  public func isNumber(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isNumber(ref, in: context.globalContextRef)
  }

  public func isNumber(in context: borrowing JSInstantContext) -> Bool {
    context.isNumber(self)
  }

  public func isString(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isString(ref, in: context.globalContextRef)
  }

  public func isString(in context: borrowing JSInstantContext) -> Bool {
    context.isString(self)
  }

  public func isSymbol(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isSymbol(ref, in: context.globalContextRef)
  }

  public func isSymbol(in context: borrowing JSInstantContext) -> Bool {
    context.isSymbol(self)
  }

  public func isObject(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isObject(ref, in: context.globalContextRef)
  }

  public func isObject(in context: borrowing JSInstantContext) -> Bool {
    context.isObject(self)
  }

  public func isBigInt(in context: borrowing JSContext) -> Bool {
    JavaScriptCoreBackendDriver.isBigInt(ref, in: context.globalContextRef)
  }

  public func isBigInt(in context: borrowing JSInstantContext) -> Bool {
    context.isBigInt(self)
  }
}
