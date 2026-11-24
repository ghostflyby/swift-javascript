import SwiftJavaScript

// MARK: - Function value initializers
//
// QuickJS mirror of `JSValueFunctionInitializers` in `SwiftyJavaScriptCore`.
// The callback closure uses the scope-keyed signature
// (`JSFunctionCallback<QJSInstantContext>`) and the produced function is the
// concrete `QJSValue`. Decoding/encoding inside the callback uses the
// conversion protocols (`JSValueDecodable`/`JSValueEncodable`) and the callback
// window's own arena; every encoded value is promoted to the context default
// scope before the handoff is built, so the carrier's borrowed handle outlives
// the callback window.

extension QJSValue {
  // MARK: Plain function callback

  public init(
    name: String,
    callback: @escaping JSFunctionCallback<QJSInstantContext>,
    in context: borrowing QJSInstantContext
  ) {
    guard
      let handle = context.driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("QJSValue(name:callback:) could not create function handle")
    }
    let adopted = context.adoptCreatedHandle(handle)
    self.init(handle: adopted.borrowHandle(), contextHandle: adopted.contextHandle)
  }

  // MARK: Typed function (decodable arguments, encodable return/error)

  public init<
    each A: JSValueDecodable,
    R: JSValueEncodable,
    Err: JSValueEncodable
  >(
    in context: isolated QJSContext = #isolation,
    name: String,
    function: @escaping @Sendable (repeat each A) throws(Err) -> R
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each A).self)
    let callback: JSFunctionCallback<QJSInstantContext> = {
      [swiftFunction] callbackContext, _, arguments in
      guard arguments.count == count else {
        return callbackContext.returnUndefined()
      }
      do {
        var index = 0
        let typedArgs: (repeat each A) = try
          (repeat try decodeFunctionArgument(
            &index,
            type: (each A).self,
            from: arguments,
            in: callbackContext
          ))
        let result: R = try swiftFunction(repeat each typedArgs)
        return callbackContext.return(try result.tryEncodeSurface(in: callbackContext))
      } catch let error as Err {
        if let encoded = try? error.tryEncodeSurface(in: callbackContext) {
          return callbackContext.throw(encoded)
        }
        return callbackContext.throwUndefined()
      } catch {
        return callbackContext.throwUndefined()
      }
    }
    let value = context.makeFunction(named: name, callback: callback)
    self.init(handle: value.borrowHandle(), contextHandle: value.contextHandle)
  }

  // MARK: Coder-based typed function

  public init<
    each C: JSValueDecoder,
    RCoder: JSValueEncoder,
    ECoder: JSValueEncoder
  >(
    in context: isolated QJSContext = #isolation,
    name: String,
    converters: repeat (each C).Type,
    returnCoder: RCoder.Type,
    errorCoder: ECoder.Type,
    function:
      @escaping @Sendable (repeat (each C).SwiftType) throws(ECoder.SwiftType) -> RCoder.SwiftType
  ) {
    let swiftFunction = function
    let count = countTypePack(repeat (each C).self)
    let callback: JSFunctionCallback<QJSInstantContext> = {
      [swiftFunction] callbackContext, _, arguments in
      guard arguments.count == count else {
        return callbackContext.returnUndefined()
      }
      do {
        var index = 0
        let typedArgs: (repeat (each C).SwiftType) = try
          (repeat try decodeFunctionArgument(
            &index,
            using: (each C).self,
            from: arguments,
            in: callbackContext
          ))
        let result: RCoder.SwiftType = try swiftFunction(repeat each typedArgs)
        return callbackContext.return(
          try RCoder.tryEncode(result, in: callbackContext))
      } catch let error as ECoder.SwiftType {
        if let encoded = try? ECoder.tryEncode(error, in: callbackContext) {
          return callbackContext.throw(encoded)
        }
        return callbackContext.throwUndefined()
      } catch {
        return callbackContext.throwUndefined()
      }
    }
    let value = context.makeFunction(named: name, callback: callback)
    self.init(handle: value.borrowHandle(), contextHandle: value.contextHandle)
  }
}

// MARK: - Conversion helpers

@inline(__always)
private func decodeFunctionArgument<T: JSValueDecodable>(
  _ index: inout Int,
  type: T.Type,
  from arguments: borrowing QJSCallbackArguments,
  in context: borrowing QJSInstantContext
) throws(JSValueConversionError) -> T {
  defer { index += 1 }
  return try arguments.withThrowingValue(at: index, in: context) {
    callbackValue throws(JSValueConversionError) -> T in
    let value = QJSValue(
      handle: callbackValue.borrowHandle(),
      contextHandle: context.driverContextHandle
    )
    return try T.tryDecode(value, in: context)
  }
}

@inline(__always)
private func decodeFunctionArgument<C: JSValueDecoder>(
  _ index: inout Int,
  using converter: C.Type,
  from arguments: borrowing QJSCallbackArguments,
  in context: borrowing QJSInstantContext
) throws(JSValueConversionError) -> C.SwiftType {
  defer { index += 1 }
  return try arguments.withThrowingValue(at: index, in: context) {
    callbackValue throws(JSValueConversionError) -> C.SwiftType in
    let value = QJSValue(
      handle: callbackValue.borrowHandle(),
      contextHandle: context.driverContextHandle
    )
    return try C.tryDecode(value, in: context)
  }
}
