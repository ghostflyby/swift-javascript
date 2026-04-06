extension JSValue {
  public init(string value: String, in context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeString(value)
    }
  }

  public init(string value: String, in context: borrowing JSInstantContext<E>) {
    self = context.makeString(value)
  }

  public init(
    string value: borrowing some JSString, in context: isolated JSContext<E> = #isolation
  ) {
    let stringValue = value.string
    self = context.withInstantContext { callbackContext in
      callbackContext.makeString(stringValue)
    }
  }

  public init(
    string value: borrowing some JSString, in context: borrowing JSInstantContext<E>
  ) {
    self = context.makeString(value.string)
  }

  public init(number value: Double, in context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeNumber(value)
    }
  }

  public init(number value: Double, in context: borrowing JSInstantContext<E>) {
    self = context.makeNumber(value)
  }

  public init(
    number value: some BinaryInteger, in context: isolated JSContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeNumber(value)
    }
  }

  public init(number value: some BinaryInteger, in context: borrowing JSInstantContext<E>) {
    self = context.makeNumber(value)
  }

  public init(boolean value: Bool, in context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeBoolean(value)
    }
  }

  public init(boolean value: Bool, in context: borrowing JSInstantContext<E>) {
    self = context.makeBoolean(value)
  }

  public init(symbol: String, in context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeSymbol(symbol)
    }
  }

  public init(symbol: String, in context: borrowing JSInstantContext<E>) {
    self = context.makeSymbol(symbol)
  }

  public init(nullIn context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeNull()
    }
  }

  public init(nullIn context: borrowing JSInstantContext<E>) {
    self = context.makeNull()
  }

  public init(undefinedIn context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeUndefined()
    }
  }

  public init(undefinedIn context: borrowing JSInstantContext<E>) {
    self = context.makeUndefined()
  }

  public init(objectIn context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeObject()
    }
  }

  public init(objectIn context: borrowing JSInstantContext<E>) {
    self = context.makeObject()
  }

  public init(arrayIn context: isolated JSContext<E> = #isolation) {
    self = context.withInstantContext { callbackContext in
      callbackContext.makeArray()
    }
  }

  public init(arrayIn context: borrowing JSInstantContext<E>) {
    self = context.makeArray()
  }
}

extension JSValue where E.Engine == E {
  public init(
    name: String,
    callback: @escaping JSEngineFunctionCallback<E>,
    in context: isolated JSContext<E> = #isolation
  ) {
    self = context.withInstantContext { callbackContext in
      JSValue(name: name, callback: callback, in: callbackContext)
    }
  }

  public init(
    name: String,
    callback: @escaping JSEngineFunctionCallback<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self = context.makeFunction(named: name, callback: callback)
  }

  public init<
    each A: JSValueDecodable,
    R: JSValueEncodable,
    Err: JSValueEncodable
  >(
    in context: isolated JSContext<E> = #isolation,
    name: String,
    function: @escaping @Sendable (repeat each A) throws(Err) -> R
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each A).self)
    let callback: JSEngineFunctionCallback<E> = { context, function, this, arguments in
      guard arguments.count == count else {
        return .value(JSValue(undefinedIn: context))
      }
      do {
        let typedArgs: (repeat each A) = try arguments.tryUnpack(
          types: repeat (each A).self,
          in: context
        )
        let r: R = try swiftFunction(repeat each typedArgs)
        let encoded = try r.tryEncode(in: context)
        return .value(encoded)
      } catch let error as Err {
        if let encoded = try? error.tryEncode(in: context) {
          return .exception(encoded)
        }
        return .exception(JSValue(undefinedIn: context))
      } catch {
        return .exception(JSValue(undefinedIn: context))
      }
    }
    self.init(name: name, callback: callback, in: context)
  }

  public init<
    each C: JSValueDecoder,
    RCoder: JSValueEncoder,
    ECoder: JSValueEncoder
  >(
    in context: isolated JSContext<E> = #isolation,
    name: String,
    converters: repeat (each C).Type,
    returnCoder: RCoder.Type,
    errorCoder: ECoder.Type,
    function:
      @escaping @Sendable (repeat (each C).SwiftType) throws(ECoder.SwiftType) -> RCoder.SwiftType
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each C).self)
    let callback: JSEngineFunctionCallback<E> = {
      [swiftFunction] context, function, this, arguments in
      guard arguments.count == count else {
        return .value(JSValue(undefinedIn: context))
      }
      do {
        let typedArgs: (repeat (each C).SwiftType) = try arguments.tryUnpack(
          using: repeat (each C).self,
          in: context
        )
        let r: RCoder.SwiftType = try swiftFunction(repeat each typedArgs)
        let encoded = try RCoder.tryEncode(r, in: context)
        return .value(encoded)
      } catch let error as ECoder.SwiftType {
        if let encoded = try? ECoder.tryEncode(error, in: context) {
          return .exception(encoded)
        }
        return .exception(JSValue(undefinedIn: context))
      } catch {
        return .exception(JSValue(undefinedIn: context))
      }
    }
    self.init(name: name, callback: callback, in: context)
  }
}
