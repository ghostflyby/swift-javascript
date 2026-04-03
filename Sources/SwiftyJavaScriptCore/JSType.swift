extension JSValue {
  public func type(in context: borrowing JSContext) -> JSType {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return type(in: instantContext)
  }

  public func type(in context: borrowing JSInstantContext) -> JSType {
    context.valueBridgeAdapter.type(of: self, in: context)
  }

  public func isUndefined(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isUndefined(in: instantContext)
  }

  public func isUndefined(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isUndefined(self, in: context)
  }

  public func isNull(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isNull(in: instantContext)
  }

  public func isNull(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isNull(self, in: context)
  }

  public func isBoolean(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isBoolean(in: instantContext)
  }

  public func isBoolean(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isBoolean(self, in: context)
  }

  public func isNumber(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isNumber(in: instantContext)
  }

  public func isNumber(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isNumber(self, in: context)
  }

  public func isString(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isString(in: instantContext)
  }

  public func isString(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isString(self, in: context)
  }

  public func isSymbol(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isSymbol(in: instantContext)
  }

  public func isSymbol(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isSymbol(self, in: context)
  }

  public func isObject(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isObject(in: instantContext)
  }

  public func isObject(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isObject(self, in: context)
  }

  public func isBigInt(in context: borrowing JSContext) -> Bool {
    let instantContext = JSInstantContext(handle: context.driverContextHandle)
    return isBigInt(in: instantContext)
  }

  public func isBigInt(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isBigInt(self, in: context)
  }
}
