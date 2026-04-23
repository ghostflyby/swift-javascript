extension JSValue {
  @_lifetime(borrow context)
  public init(string value: String, in context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeString(value)
  }

  @_lifetime(borrow context)
  public init(string value: String, in context: borrowing JSInstantContext<E>) {
    self = context.makeString(value)
  }

  @_lifetime(borrow context)
  public init(
    string value: borrowing some JSString,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    self = context.makeString(value.string)
  }

  @_lifetime(borrow context)
  public init(
    string value: borrowing some JSString, in context: borrowing JSInstantContext<E>
  ) {
    self = context.makeString(value.string)
  }

  @_lifetime(borrow context)
  public init(number value: Double, in context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeNumber(value)
  }

  @_lifetime(borrow context)
  public init(number value: Double, in context: borrowing JSInstantContext<E>) {
    self = context.makeNumber(value)
  }

  @_lifetime(borrow context)
  public init(
    number value: some BinaryInteger,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    self = context.makeNumber(Double(value))
  }

  @_lifetime(borrow context)
  public init(number value: some BinaryInteger, in context: borrowing JSInstantContext<E>) {
    self = context.makeNumber(value)
  }

  @_lifetime(borrow context)
  public init(boolean value: Bool, in context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeBoolean(value)
  }

  @_lifetime(borrow context)
  public init(boolean value: Bool, in context: borrowing JSInstantContext<E>) {
    self = context.makeBoolean(value)
  }

  @_lifetime(borrow context)
  public init(symbol: String, in context: borrowing isolated JSContext<E> = #isolation) {
    guard let handle = E.makeSymbolValueHandle(symbol, context.driverContextHandle) else {
      preconditionFailure("JSValue.init(symbol:in:) could not create handle")
    }
    self = JSValue(handleValue: handle)
  }

  @_lifetime(borrow context)
  public init(symbol: String, in context: borrowing JSInstantContext<E>) {
    self = context.makeSymbol(symbol)
  }

  @_lifetime(borrow context)
  public init(nullIn context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeNull()
  }

  @_lifetime(borrow context)
  public init(nullIn context: borrowing JSInstantContext<E>) {
    self = context.makeNull()
  }

  @_lifetime(borrow context)
  public init(undefinedIn context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeUndefined()
  }

  @_lifetime(borrow context)
  public init(undefinedIn context: borrowing JSInstantContext<E>) {
    self = context.makeUndefined()
  }

  @_lifetime(borrow context)
  public init(objectIn context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeObject()
  }

  @_lifetime(borrow context)
  public init(objectIn context: borrowing JSInstantContext<E>) {
    self = context.makeObject()
  }

  @_lifetime(borrow context)
  public init(arrayIn context: borrowing isolated JSContext<E> = #isolation) {
    self = context.makeArray()
  }

  @_lifetime(borrow context)
  public init(arrayIn context: borrowing JSInstantContext<E>) {
    self = context.makeArray()
  }
}

extension JSValue where E.Engine == E {
  @_lifetime(borrow context)
  public init(
    name: String,
    callback: @escaping JSFunctionCallback<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    guard
      let handle = E.makeFunctionValueHandle(
        named: name,
        callback: retainedFunctionCallback(callback),
        in: context.driverContextHandle
      )
    else {
      preconditionFailure("JSValue.init(name:callback:in:) could not create handle")
    }
    self = JSValue(handleValue: handle)
  }

  @_lifetime(borrow context)
  public init(
    name: String,
    callback: @escaping JSFunctionCallback<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self = context.makeFunction(named: name, callback: callback)
  }

  @_lifetime(borrow context)
  public init<
    each A: JSValueDecodable,
    R: JSValueEncodable,
    Err: JSValueEncodable
  >(
    in context: borrowing isolated JSContext<E> = #isolation,
    name: String,
    function: @escaping @Sendable (repeat each A) throws(Err) -> R
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each A).self)
    let callback: JSFunctionCallback<E> = { context, this, arguments in
      guard arguments.count == count else {
        let undefined = JSValue(undefinedIn: context)
        return .value(JSValue(retaining: undefined))
      }
      do {
        let typedArgs: (repeat each A) = try arguments.tryUnpack(
          types: repeat (each A).self,
          in: context
        )
        let r: R = try swiftFunction(repeat each typedArgs)
        let encoded = try r.tryEncode(in: context)
        return .value(JSValue(retaining: encoded))
      } catch let error as Err {
        if let encoded = try? error.tryEncode(in: context) {
          return .exception(JSValue(retaining: encoded))
        }
        let undefined = JSValue(undefinedIn: context)
        return .exception(JSValue(retaining: undefined))
      } catch {
        let undefined = JSValue(undefinedIn: context)
        return .exception(JSValue(retaining: undefined))
      }
    }
    self.init(name: name, callback: callback, in: context)
  }

  @_lifetime(borrow context)
  public init<
    each C: JSValueDecoder,
    RCoder: JSValueEncoder,
    ECoder: JSValueEncoder
  >(
    in context: borrowing isolated JSContext<E> = #isolation,
    name: String,
    converters: repeat (each C).Type,
    returnCoder: RCoder.Type,
    errorCoder: ECoder.Type,
    function:
      @escaping @Sendable (repeat (each C).SwiftType) throws(ECoder.SwiftType) -> RCoder.SwiftType
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each C).self)
    let callback: JSFunctionCallback<E> = {
      [swiftFunction] context, this, arguments in
      guard arguments.count == count else {
        let undefined = JSValue(undefinedIn: context)
        return .value(JSValue(retaining: undefined))
      }
      do {
        let typedArgs: (repeat (each C).SwiftType) = try arguments.tryUnpack(
          using: repeat (each C).self,
          in: context
        )
        let r: RCoder.SwiftType = try swiftFunction(repeat each typedArgs)
        let encoded = try RCoder.tryEncode(r, in: context)
        return .value(JSValue(retaining: encoded))
      } catch let error as ECoder.SwiftType {
        if let encoded = try? ECoder.tryEncode(error, in: context) {
          return .exception(JSValue(retaining: encoded))
        }
        let undefined = JSValue(undefinedIn: context)
        return .exception(JSValue(retaining: undefined))
      } catch {
        let undefined = JSValue(undefinedIn: context)
        return .exception(JSValue(retaining: undefined))
      }
    }
    self.init(name: name, callback: callback, in: context)
  }
}
