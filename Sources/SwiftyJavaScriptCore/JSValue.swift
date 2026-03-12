//
//  File.swift
//  SwiftyJavaScriptCore
//
//  Created by ghostflyby pan on 2025/9/12.
//
import JavaScriptCore

@inline(__always)
func countTypePack<each T>(_ types: repeat (each T).Type) -> Int {
  var count = 0
  for _ in repeat each types {
    count += 1
  }
  return count
}

public struct JSValue: ~Copyable {
  let ref: JSValueRef
  let ctx: JSContextRef

  /// Wrap the `ref` **without retaining**
  /// - Parameters:
  ///   - ref: The JSValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JSValueRef, ctx: isolated JSContext = #isolation) {
    self.ref = ref
    self.ctx = ctx.globalContextRef
  }

  init(ref: JSValueRef, ctx: borrowing JSInstantContext) {
    self.ref = ref
    self.ctx = ctx.globalContextRef
  }

  public init(string value: String, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeString(
      context.globalContextRef, JSStringCreateWithCFString(value as CFString))
    self.init(ref: s!, ctx: context)
  }

  public init(string value: String, in context: borrowing JSInstantContext) {
    let s = JSValueMakeString(
      context.globalContextRef, JSStringCreateWithCFString(value as CFString))
    self.init(ref: s!, ctx: context)
  }

  public init(string value: borrowing JSString, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeString(context.globalContextRef, value.ref)
    self.init(ref: s!, ctx: context)
  }

  public init(number value: Double, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeNumber(context.globalContextRef, value)
    self.init(ref: s!, ctx: context)
  }

  public init(number value: Double, in context: borrowing JSInstantContext) {
    let s = JSValueMakeNumber(context.globalContextRef, value)
    self.init(ref: s!, ctx: context)
  }

  public init(number value: some BinaryInteger, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeNumber(context.globalContextRef, Double(value))
    self.init(ref: s!, ctx: context)
  }

  public init(number value: some BinaryInteger, in context: borrowing JSInstantContext) {
    let s = JSValueMakeNumber(context.globalContextRef, Double(value))
    self.init(ref: s!, ctx: context)
  }

  public init(boolean value: Bool, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeBoolean(context.globalContextRef, value)
    self.init(ref: s!, ctx: context)
  }

  public init(boolean value: Bool, in context: borrowing JSInstantContext) {
    let s = JSValueMakeBoolean(context.globalContextRef, value)
    self.init(ref: s!, ctx: context)
  }

  public init(symbol: String, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeSymbol(
      context.globalContextRef, JSStringCreateWithCFString(symbol as CFString))
    self.init(ref: s!, ctx: context)
  }

  public init(nullIn context: isolated JSContext = #isolation) {
    let s = JSValueMakeNull(context.globalContextRef)
    self.init(ref: s!, ctx: context)
  }

  public init(nullIn context: borrowing JSInstantContext) {
    let s = JSValueMakeNull(context.globalContextRef)
    self.init(ref: s!, ctx: context)
  }

  public init(undefinedIn context: isolated JSContext = #isolation) {
    let s = JSValueMakeUndefined(context.globalContextRef)
    self.init(ref: s!, ctx: context)
  }

  public init(undefinedIn context: borrowing JSInstantContext) {
    let s = JSValueMakeUndefined(context.globalContextRef)
    self.init(ref: s!, ctx: context)
  }

  public init(objectIn context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(objectIn: callbackContext)
  }

  public init(objectIn context: borrowing JSInstantContext) {
    switch JavaScriptCoreBackendDriver.makeObject(in: context.driverContext) {
    case .exception:
      preconditionFailure("JSValue object creation raised exception")
    case .value(let object):
      self.init(rawValue: object)
    }
  }

  public init(arrayIn context: isolated JSContext = #isolation) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    self.init(arrayIn: callbackContext)
  }

  public init(arrayIn context: borrowing JSInstantContext) {
    switch JavaScriptCoreBackendDriver.makeArray(in: context.driverContext) {
    case .exception:
      preconditionFailure("JSValue array creation raised exception")
    case .value(let array):
      self.init(rawValue: array)
    }
  }

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
    let jsFunctionRef = JSObjectMake(
      context.globalContextRef, context.functionClass.value,
      Unmanaged.passRetained(Box(callback)).toOpaque())

    self.init(ref: jsFunctionRef!, ctx: context)
  }

  public init(
    name: String,
    callback: @escaping JSFunctionCallback,
    in context: borrowing JSInstantContext
  ) {
    let jsFunctionRef = JSObjectMake(
      context.globalContextRef,
      context.actorContext.functionClass.value,
      Unmanaged.passRetained(Box(callback)).toOpaque()
    )

    self.init(ref: jsFunctionRef!, ctx: context)
  }

  private consuming func toSendableBox() -> SendableBoxUnsafe<JSValue> {
    return SendableBoxUnsafe(self)
  }

  consuming func retainedRef() -> JSValueRef {
    let ref = ref
    discard self
    return ref
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

  deinit {
    JSValueUnprotect(ctx, ref)
  }
}

extension JSValue {
  init(rawValue: JavaScriptCoreRawValue) {
    self.init(ref: rawValue.ref, ctx: JSInstantContext(ctx: rawValue.context.ref))
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: ref, context: context)
  }
}

extension JSResult {
  consuming func toPrivateResult() -> JSPrivateResult {
    switch consume self {
    case .value(let v):
      return .value(v.retainedRef())
    case .exception(let e):
      return .exception(e.retainedRef())
    }
  }
}

extension JSResult {
  static func from(driverResult: JSDriverResult<JavaScriptCoreRawValue>) -> JSResult {
    switch driverResult {
    case .value(let value):
      return .value(JSValue(rawValue: value))
    case .exception(let exception):
      return .exception(JSValue(rawValue: exception))
    }
  }
}
public enum JSResult: ~Copyable {
  case value(JSValue)
  case exception(JSValue)
}

enum JSPrivateResult: @unchecked Sendable {
  case value(JSValueRef)
  case exception(JSValueRef)
}

class Box<T: ~Copyable> {
  let value: T
  init(_ value: consuming T) {
    self.value = value
  }
}

struct SendableBoxUnsafe<T: ~Copyable>: @unchecked Sendable, ~Copyable {
  let value: T
  init(_ value: consuming T) {
    self.value = value
  }
}

extension SendableBoxUnsafe: Copyable where T: Copyable {}

extension JSValue {
  public static func == (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx
      && JSValueIsEqual(lhs.ctx, lhs.ref, rhs.ref, nil)
  }

  public static func != (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return !(lhs == rhs)
  }

  public static func === (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx && JSValueIsStrictEqual(lhs.ctx, lhs.ref, rhs.ref)
  }

  public static func !== (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return !(lhs === rhs)
  }
}

extension JSValue {
  @inline(__always)
  private static func result(
    value resultRef: JSValueRef?,
    exception exceptionRef: JSValueRef?,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    if let exceptionRef {
      return .exception(JSValue(ref: exceptionRef, ctx: context))
    }

    if let resultRef {
      return .value(JSValue(ref: resultRef, ctx: context))
    }

    return .value(JSValue(undefinedIn: context))
  }

  @inline(__always)
  private func objectRef(in context: borrowing JSInstantContext) -> JSPrivateResult {
    var exception: JSValueRef?
    guard let objectRef = JSValueToObject(context.globalContextRef, self.ref, &exception) else {
      let exceptionValue = exception ?? JSValue(undefinedIn: context).retainedRef()
      return .exception(exceptionValue)
    }
    return .value(objectRef)
  }

  @inline(__always)
  private func callInternal(
    thisRawValue: JavaScriptCoreRawValue?,
    arguments: [JavaScriptCoreRawValue],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let rawContext = context.driverContext
    return .from(
      driverResult: JavaScriptCoreBackendDriver.callFunction(
        rawValue(in: rawContext),
        this: thisRawValue,
        arguments: arguments,
        in: rawContext
      ))
  }

  @inline(__always)
  private func constructInternal(
    arguments: [JavaScriptCoreRawValue],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let rawContext = context.driverContext
    return .from(
      driverResult: JavaScriptCoreBackendDriver.construct(
        rawValue(in: rawContext),
        arguments: arguments,
        in: rawContext
      ))
  }

  @inline(__always)
  private func encodedArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> [JavaScriptCoreRawValue] {
    let rawContext = context.driverContext
    var values: [JavaScriptCoreRawValue] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded = (try? argument.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
      values.append(encoded.rawValue(in: rawContext))
    }

    repeat appendArgument(each arguments)
    return values
  }

  public func call(in context: isolated JSContext = #isolation) -> JSResult {
    context.withInstantContext { callbackContext in
      call(in: callbackContext)
    }
  }

  public func call(in context: borrowing JSInstantContext) -> JSResult {
    callInternal(thisRawValue: nil, arguments: [], in: context)
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      call(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    callInternal(
      thisRawValue: nil, arguments: encodedArguments(repeat each arguments, in: context),
      in: context)
  }

  public func call(
    this thisValue: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      call(this: thisValue, in: callbackContext)
    }
  }

  public func call(
    this thisValue: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    callInternal(
      thisRawValue: thisValue.rawValue(in: context.driverContext), arguments: [], in: context)
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      call(this: thisValue, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    callInternal(
      thisRawValue: thisValue.rawValue(in: context.driverContext),
      arguments: encodedArguments(repeat each arguments, in: context),
      in: context
    )
  }

  public func construct(in context: isolated JSContext = #isolation) -> JSResult {
    context.withInstantContext { callbackContext in
      construct(in: callbackContext)
    }
  }

  public func construct(in context: borrowing JSInstantContext) -> JSResult {
    constructInternal(arguments: [], in: context)
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      construct(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    constructInternal(arguments: encodedArguments(repeat each arguments, in: context), in: context)
  }

  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: isolated JSContext = #isolation
  ) -> JSResult where Name: ~Copyable {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: borrowing JSInstantContext
  ) -> JSResult where Name: ~Copyable {
    invokeMethodInternal(name.string, arguments: [], in: context)
  }

  public func invokeMethod<each A: JSValueEncodable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult where Name: ~Copyable {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult where Name: ~Copyable {
    invokeMethodInternal(
      name.string,
      arguments: encodedArguments(repeat each arguments, in: context),
      in: context
    )
  }

  private func invokeMethodInternal(
    _ name: String,
    arguments: [JavaScriptCoreRawValue],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let rawContext = context.driverContext
    switch JavaScriptCoreBackendDriver.getProperty(
      name, on: rawValue(in: rawContext), in: rawContext)
    {
    case .exception(let exception):
      return .exception(JSValue(rawValue: exception))
    case .value(let method):
      return .from(
        driverResult: JavaScriptCoreBackendDriver.callFunction(
          method,
          this: rawValue(in: rawContext),
          arguments: arguments,
          in: rawContext
        ))
    }
  }

  public func toNumber(in context: isolated JSContext = #isolation) -> Double {
    toDouble(in: context)
  }

  public func toNumber(in context: borrowing JSInstantContext) -> Double {
    toDouble(in: context)
  }

  public func toObject(in context: isolated JSContext = #isolation) -> JSResult {
    context.withInstantContext { callbackContext in
      toObject(in: callbackContext)
    }
  }

  public func toObject(in context: borrowing JSInstantContext) -> JSResult {
    let rawContext = context.driverContext
    return .from(
      driverResult: JavaScriptCoreBackendDriver.toObject(rawValue(in: rawContext), in: rawContext))
  }

  public func isArray(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext) -> Bool {
    let rawContext = context.driverContext
    return JavaScriptCoreBackendDriver.isArray(rawValue(in: rawContext), in: rawContext)
  }

  public func isDate(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isDate(in: callbackContext)
    }
  }

  public func isDate(in context: borrowing JSInstantContext) -> Bool {
    let rawContext = context.driverContext
    return JavaScriptCoreBackendDriver.isDate(rawValue(in: rawContext), in: rawContext)
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      isInstanceOf(constructor, in: callbackContext)
    }
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    let rawContext = context.driverContext
    return JavaScriptCoreBackendDriver.isInstanceOf(
      rawValue(in: rawContext),
      constructor: constructor.rawValue(in: rawContext),
      in: rawContext
    )
  }

  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) -> JSResult where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    context.withInstantContext { callbackContext in
      defineProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) -> JSResult where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    let rawContext = context.driverContext
    switch JavaScriptCoreBackendDriver.setProperty(
      key.string,
      on: rawValue(in: rawContext),
      to: encoded.rawValue(in: rawContext),
      in: rawContext,
      attributes: attributes.hostMemberAttributes
    ) {
    case .exception:
      return .exception(JSValue(undefinedIn: context))
    case .value:
      switch JavaScriptCoreBackendDriver.getProperty(
        key.string, on: rawValue(in: rawContext), in: rawContext)
      {
      case .exception(let exception):
        return .exception(JSValue(rawValue: exception))
      case .value(let stored):
        return .value(JSValue(rawValue: stored))
      }
    }
  }
}
