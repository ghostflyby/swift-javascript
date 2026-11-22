extension JSValue where E: JSEngineRuntimeDriver {
  public init(string value: String, in context: isolated JSContext<E> = #isolation)
  where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeString(value))
      })
  }

  public init(string value: String, in context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeString(value)))
  }

  public init(
    string key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeString(from: key))
      })
  }

  public init(
    string key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) where E: JSEnginePropertyDriver {
    self.init(taking: context.persist(context.makeString(from: key)))
  }

  public init(number value: Double, in context: isolated JSContext<E> = #isolation)
  where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeNumber(value))
      })
  }

  public init(number value: Double, in context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeNumber(value)))
  }

  public init(
    number value: some BinaryInteger, in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeNumber(value))
      })
  }

  public init(number value: some BinaryInteger, in context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeNumber(value)))
  }

  public init(boolean value: Bool, in context: isolated JSContext<E> = #isolation)
  where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeBoolean(value))
      })
  }

  public init(boolean value: Bool, in context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeBoolean(value)))
  }

  public init(symbol: String, in context: isolated JSContext<E> = #isolation)
  where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeSymbol(symbol))
      })
  }

  public init(symbol: String, in context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeSymbol(symbol)))
  }

  public init(nullIn context: isolated JSContext<E> = #isolation) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeNull())
      })
  }

  public init(nullIn context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeNull()))
  }

  public init(undefinedIn context: isolated JSContext<E> = #isolation) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        callbackContext.persist(callbackContext.makeUndefined())
      })
  }

  public init(undefinedIn context: borrowing JSInstantContext<E>) {
    self.init(taking: context.persist(context.makeUndefined()))
  }

  public init(objectIn context: isolated JSContext<E> = #isolation) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        let result = callbackContext.makeObject()
        guard case .value(let cb) = result else {
          preconditionFailure("makeObject failed")
        }
        return callbackContext.persist(cb)
      })
  }

  public init(objectIn context: borrowing JSInstantContext<E>) {
    let result = context.makeObject()
    guard case .value(let cb) = result else {
      preconditionFailure("makeObject failed")
    }
    self.init(taking: context.persist(cb))
  }

  public init(arrayIn context: isolated JSContext<E> = #isolation) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        let result = callbackContext.makeArray()
        guard case .value(let cb) = result else {
          preconditionFailure("makeArray failed")
        }
        return callbackContext.persist(cb)
      })
  }

  public init(arrayIn context: borrowing JSInstantContext<E>) {
    let result = context.makeArray()
    guard case .value(let cb) = result else {
      preconditionFailure("makeArray failed")
    }
    self.init(taking: context.persist(cb))
  }
}

extension JSValue where E: JSEngineRuntimeDriver, E.Engine == E {
  public init(
    name: String,
    callback: @escaping JSFunctionCallback<E>,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    self.init(
      taking: context.withInstantContext { callbackContext in
        JSValue(name: name, callback: callback, in: callbackContext)
      })
  }

  public init(
    name: String,
    callback: @escaping JSFunctionCallback<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    self.init(taking: context.makeFunction(named: name, callback: callback))
  }

  public init<
    each A: JSValueDecodable,
    R: JSValueEncodable,
    Err: JSValueEncodable
  >(
    in context: isolated JSContext<E> = #isolation,
    name: String,
    function: @escaping @Sendable (repeat each A) throws(Err) -> R
  ) where E: JSContextEngine & JSValueConversionEngine {
    let swiftFunction = function
    let count = countTypePack(repeat (each A).self)
    let callback: JSFunctionCallback<E> = { context, this, arguments in
      guard arguments.count == count else {
        return context.returnUndefined()
      }
      do {
        let typedArgs: (repeat each A) = try arguments.tryUnpack(
          types: repeat (each A).self,
          in: context
        )
        let r: R = try swiftFunction(repeat each typedArgs)
        let encoded = try r.tryEncode(in: context)
        return JSCallbackReturn(persistent: encoded)
      } catch let error as Err {
        if let encoded = try? error.tryEncode(in: context) {
          let cb = JSCallbackValue<E>(
            handle: encoded.borrowHandle(), context: context.driverContextHandle)
          return context.throw(cb)
        }
        return context.throwUndefined()
      } catch {
        return context.throwUndefined()
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
  ) where E: JSContextEngine & JSValueConversionEngine {
    let swiftFunction = function
    let count = countTypePack(repeat (each C).self)
    let callback: JSFunctionCallback<E> = {
      [swiftFunction] context, this, arguments in
      guard arguments.count == count else {
        return context.returnUndefined()
      }
      do {
        let typedArgs: (repeat (each C).SwiftType) = try arguments.tryUnpack(
          using: repeat (each C).self,
          in: context
        )
        let r: RCoder.SwiftType = try swiftFunction(repeat each typedArgs)
        let encoded = try RCoder.tryEncode(r, in: context)
        return JSCallbackReturn(persistent: encoded)
      } catch let error as ECoder.SwiftType {
        if let encoded = try? ECoder.tryEncode(error, in: context) {
          let cb = JSCallbackValue<E>(
            handle: encoded.borrowHandle(), context: context.driverContextHandle)
          return context.throw(cb)
        }
        return context.throwUndefined()
      } catch {
        return context.throwUndefined()
      }
    }
    self.init(name: name, callback: callback, in: context)
  }
}
