//
//  File.swift
//  SwiftyJavaScriptCore
//
//  Created by ghostflyby pan on 2025/9/12.
//
public struct JSValue: ~Copyable {
  let _rawValue: _JSValueRawStorage

  public init(string value: String, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeString(value)
  }

  public init(string value: String, in context: borrowing JSInstantContext) {
    self = context.makeString(value)
  }

  public init(string value: borrowing JSString, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeString(value.string)
  }

  public init(number value: Double, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeNumber(value)
  }

  public init(number value: Double, in context: borrowing JSInstantContext) {
    self = context.makeNumber(value)
  }

  public init(number value: some BinaryInteger, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeNumber(value)
  }

  public init(number value: some BinaryInteger, in context: borrowing JSInstantContext) {
    self = context.makeNumber(value)
  }

  public init(boolean value: Bool, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeBoolean(value)
  }

  public init(boolean value: Bool, in context: borrowing JSInstantContext) {
    self = context.makeBoolean(value)
  }

  public init(symbol: String, in context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeSymbol(symbol)
  }

  public init(nullIn context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeNull()
  }

  public init(nullIn context: borrowing JSInstantContext) {
    self = context.makeNull()
  }

  public init(undefinedIn context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self = callbackContext.makeUndefined()
  }

  public init(undefinedIn context: borrowing JSInstantContext) {
    self = context.makeUndefined()
  }

  public init(objectIn context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(objectIn: callbackContext)
  }

  public init(objectIn context: borrowing JSInstantContext) {
    self = context.makeObject()
  }

  public init(arrayIn context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(arrayIn: callbackContext)
  }

  public init(arrayIn context: borrowing JSInstantContext) {
    self = context.makeArray()
  }
}

extension JSValue {
  public typealias JSFunctionCallback =
    (
      _ context: borrowing JSInstantContext, _ function: borrowing JSValue,
      _ this: borrowing JSValue,
      _ arguments: borrowing JSArguments
    ) -> JSResult

  public init(
    name: String,
    callback: @escaping JSFunctionCallback,
    in context: isolated JSContext = #isolation,
  ) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(name: name, callback: callback, in: callbackContext)
  }

  public init(
    name: String,
    callback: @escaping JSFunctionCallback,
    in context: borrowing JSInstantContext
  ) {
    let function = JavaScriptCoreBackendDriver.makeFunction(
      named: name,
      callback: callback,
      in: context.driverContext,
      functionClass: context.actorContext.functionClass.value
    )
    self.init(rawValue: function)
  }

  private consuming func toSendableBox() -> SendableBoxUnsafe<JSValue> {
    return SendableBoxUnsafe(self)
  }

  public init<
    each A: JSValueDecodable,
    R: JSValueEncodable,
    E: JSValueEncodable
  >(
    in context: isolated JSContext = #isolation, name: String,
    function: @escaping @Sendable (repeat each A) throws(E) -> R
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each A).self)
    let callback: JSFunctionCallback = { context, function, this, arguments in
      guard arguments.count == count else {
        return JSResult.value(JSValue(undefinedIn: context))
      }
      do {
        let typedArgs: (repeat each A) = try arguments.tryUnpack(
          types: repeat (each A).self,
          in: context
        )
        let r: R = try swiftFunction(repeat each typedArgs)
        let encoded = try r.tryEncode(in: context)
        return .value(encoded)
      } catch let error as E {
        if let encoded = try? error.tryEncode(in: context) {
          return .exception(encoded)
        }
        return .exception(JSValue(undefinedIn: context))
      } catch {
        return .exception(JSValue(undefinedIn: context))
      }
    }
    self.init(name: name, callback: callback)
  }

  public init<
    each C: JSValueDecoder,
    RCoder: JSValueEncoder,
    ECoder: JSValueEncoder
  >(
    in context: isolated JSContext = #isolation,
    name: String,
    converters: repeat (each C).Type,
    returnCoder: RCoder.Type,
    errorCoder: ECoder.Type,
    function:
      @escaping @Sendable (repeat (each C).SwiftType) throws(ECoder.SwiftType) -> RCoder.SwiftType
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each C).self)
    let callback: JSFunctionCallback = { [swiftFunction] context, function, this, arguments in
      guard arguments.count == count else {
        return JSResult.value(JSValue(undefinedIn: context))
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
    self.init(name: name, callback: callback)
  }
}
