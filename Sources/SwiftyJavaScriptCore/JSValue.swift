//
//  File.swift
//  SwiftyJavaScriptCore
//
//  Created by ghostflyby pan on 2025/9/12.
//
import JavaScriptCore

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

  public init(string value: String, in context: isolated JSContext = #isolation) {
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

  public init(number value: some BinaryInteger, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeNumber(context.globalContextRef, Double(value))
    self.init(ref: s!, ctx: context)
  }

  public init(boolean value: Bool, in context: isolated JSContext = #isolation) {
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

  public init(undefinedIn context: isolated JSContext = #isolation) {
    let s = JSValueMakeUndefined(context.globalContextRef)
    self.init(ref: s!, ctx: context)
  }

  public typealias JSFunctionCallback =
    (
      _ context: isolated JSContext, _ function: borrowing JSValue,
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

  private consuming func toSendableBox() -> SendableBoxUnsafe<JSValue> {
    return SendableBoxUnsafe(self)
  }

  consuming func retainedRef() -> JSValueRef {
    let ref = ref
    discard self
    return ref
  }

  public init<each A: JSValueDecodable, R: JSValueEncodable, E: JSValueEncodable>(
    in context: isolated JSContext = #isolation, name: String,
    function: @escaping @Sendable (repeat each A) throws(E) -> R
  ) {
    let swiftFunction = function
    let count = Mirror(reflecting: (repeat (each A).self)).children.count
    let callback: JSFunctionCallback = { context, function, this, arguments in
      guard arguments.count == count else {
        return JSResult.value(JSValue(undefinedIn: context))
      }
      let typedArgs: (repeat each A) = arguments.unpack(types: repeat (each A).self)
      do {
        let r: R = try swiftFunction(repeat each typedArgs)
        return JSResult.value(r.toJSValue(in: context))
      } catch let error as E {
        return JSResult.exception(error.toJSValue(in: context))
      } catch {
        return JSResult.exception(JSValue(undefinedIn: context))
      }
    }
    self.init(name: name, callback: callback)
  }

  public init<each C: JSValueConverter, R: JSValueEncodable, E: JSValueEncodable>(
    in context: isolated JSContext = #isolation,
    name: String,
    converters: repeat (each C).Type,
    function: @escaping @Sendable (repeat (each C).SwiftType) throws(E) -> R
  ) {
    let swiftFunction = function
    let count = Mirror(reflecting: (repeat (each C).self)).children.count
    let callback: JSFunctionCallback = { context, function, this, arguments in
      guard arguments.count == count else {
        return JSResult.value(JSValue(undefinedIn: context))
      }
      let typedArgs: (repeat (each C).SwiftType) = arguments.unpack(
        using: repeat (each C).self,
        in: context
      )
      do {
        let r: R = try swiftFunction(repeat each typedArgs)
        return JSResult.value(r.toJSValue(in: context))
      } catch let error as E {
        return JSResult.exception(error.toJSValue(in: context))
      } catch {
        return JSResult.exception(JSValue(undefinedIn: context))
      }
    }
    self.init(name: name, callback: callback)
  }

  deinit {
    JSValueUnprotect(ctx, ref)
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
public enum JSResult: ~Copyable {
  case value(JSValue)
  case exception(JSValue)
}

enum JSPrivateResult: @unchecked Sendable {
  case value(JSValueRef)
  case exception(JSValueRef)
}

public struct JSArguments: ~Copyable {
  let pointer: UnsafePointer<JSValueRef?>
  let count: Int

  public func unpack<R: ~Copyable>(
    at: Int, in context: isolated JSContext = #isolation, _ body: (borrowing JSValue) -> R
  ) -> R {
    guard at >= 0 && at < count else {
      fatalError("Index out of bounds")
    }
    let value =
      if let v = pointer[at] {
        JSValue(ref: v, ctx: context)
      } else {
        JSValue(undefinedIn: context)
      }
    return body(value)
  }

  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type, in context: isolated JSContext = #isolation
  ) -> (repeat each T) {
    var idx = 0
    let pointer = self.pointer
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: context)
      } else {
        return JSValue(undefinedIn: context)
      }
    }
    return
      (repeat (each T).init(value: nextJSValue(), in: context))

  }

  public func unpack<C: JSValueConverter>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    unpack(at: at, in: context) { value in
      converter.decode(value, in: context)
    }
  }

  public func unpack<each C: JSValueConverter>(
    using converters: repeat (each C).Type,
    in context: isolated JSContext = #isolation
  ) -> (repeat (each C).SwiftType) {
    var idx = 0
    let pointer = self.pointer
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: context)
      } else {
        return JSValue(undefinedIn: context)
      }
    }

    return
      (repeat (each C).decode(nextJSValue(), in: context))
  }
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
