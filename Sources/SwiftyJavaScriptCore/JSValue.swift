//
//  File.swift
//  SwiftyJavaScriptCore
//
//  Created by ghostflyby pan on 2025/9/12.
//

import Foundation
@preconcurrency import JavaScriptCore.JSValueRef

public protocol JSValueMarshal: ~Copyable, Sendable {
  init(value: borrowing JSValue, in context: isolated JSContext)
  func toJSValue(in context: isolated JSContext) -> JSValue
}

public struct JSValue: ~Copyable {
  let ref: JSValueRef
  let ctx: JSContext

  /// Wrap the `ref` **without retaining**
  /// - Parameters:
  ///   - ref: The JSValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JSValueRef, ctx: isolated JSContext = #isolation) {
    self.ref = ref
    self.ctx = ctx
  }

  public init(string value: String, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeString(context.globalContextRef, JSStringValue(value).ref)
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
    @Sendable (
      _ context: isolated JSContext, _ function: borrowing JSValue,
      _ this: borrowing JSValue,
      _ arguments: borrowing Span<JSValue>
    ) -> JSResult

  public init(
    name: String,
    callback: @escaping JSFunctionCallback,
    in context: isolated JSContext = #isolation,
  ) {
    let jsFunctionRef = JSObjectMakeFunctionWithCallback(
      context.globalContextRef, JSStringCreateWithCFString(name as CFString),
      { c, f, this, count, args, exception in
        // FIXME: use the real context instead of creating a new one
        let context = JSContext(virtualMachine: JSVirtualMachine())
        let f = SendableBoxUnsafe(f!)
        let this = SendableBoxUnsafe(this!)
        let args = SendableBoxUnsafe(args!)

        let v = context.assumeIsolated { context in
          let function = JSValue(ref: f.value, ctx: context).toSendableBox()
          let this = JSValue(ref: this.value, ctx: context).toSendableBox()
          let buffer = UnsafeMutableBufferPointer<JSValue>.allocate(capacity: Int(count))
          let args = Span<JSValueRef?>(_unsafeStart: args.value, count: Int(count))
          for i in 0..<count {
            let arg = args[i] ?? JSValueMakeNull(context.globalContextRef)!
            buffer.initializeElement(at: i, to: JSValue(ref: arg, ctx: context))
          }
          defer {
            buffer.deinitialize().deallocate()
          }
          let span = buffer.span
          // FIXME:
          let callback = Unmanaged<Box<JSFunctionCallback>>.fromOpaque(JSObjectGetPrivate(f.value)!)
            .takeUnretainedValue().value
          let callbackResult = callback(
            context,
            function.value,
            this.value,
            span
          )

          switch callbackResult {
          case .value(let value):
            return JSPrivateResult.value(value.retainedRef)
          case .exception(let error):
            return JSPrivateResult.value(error.retainedRef)
          }
        }
        switch v {
        case .value(let r):
          return r
        case .exception(let e):
          exception?.pointee = e
          return JSValueMakeUndefined(c!)
        }
      })
    JSObjectSetPrivate(jsFunctionRef, Unmanaged.passRetained(Box(callback)).toOpaque())
    self.init(ref: jsFunctionRef!, ctx: context)
  }

  public enum JSResult: ~Copyable {
    case value(JSValue)
    case exception(JSValue)
  }

  private enum JSPrivateResult: @unchecked Sendable {
    case value(JSValueRef)
    case exception(JSValueRef)
  }

  private consuming func toSendableBox() -> SendableBoxUnsafe<JSValue> {
    return SendableBoxUnsafe(self)
  }

  private var retainedRef: JSValueRef {
    JSValueProtect(ctx.globalContextRef, ref)
    return ref
  }

  public init<each A: JSValueMarshal, R: JSValueMarshal, E: JSValueMarshal>(
    in context: isolated JSContext = #isolation, name: String,
    function: @escaping @Sendable (repeat each A) throws(E) -> R
  ) {
    let swiftFunction = function
    let count = Mirror(reflecting: (repeat each A).self).children.count
    self.init(name: name) { context, function, this, arguments in
      guard arguments.count == count else {
        return .value(JSValue(undefinedIn: context))
      }
      var idx = 0
      let nextIndex = {
        defer { idx += 1 }
        return idx
      }
      let typedArgs: (repeat each A) =
        (repeat (each A).init(value: arguments[nextIndex()], in: context))
      do {
        let r = try swiftFunction(repeat each typedArgs)
        return .value(r.toJSValue(in: context))
      } catch let error as E {
        return .exception(error.toJSValue(in: context))
      } catch {
        return .value(JSValue(undefinedIn: context))
      }
    }
  }

  deinit {
    JSValueUnprotect(ctx.globalContextRef, ref)
  }
}

public struct JSArguments: ~Copyable {
  let pointer: UnsafePointer<JSValueRef?>
  let count: Int
  let ctx: JSContext

  public func run<R: ~Copyable>(
    at: Int, in context: isolated JSContext = #isolation, body: (borrowing JSValue) -> R
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
}

private class Box<T: ~Copyable> {
  let value: T
  init(_ value: consuming T) {
    self.value = value
  }
}

private struct SendableBoxUnsafe<T: ~Copyable>: @unchecked Sendable, ~Copyable {
  let value: T
  init(_ value: consuming T) {
    self.value = value
  }
}

extension JSValue {
  public static func == (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx
      && JSValueIsEqual(lhs.ctx.globalContextRef, lhs.ref, rhs.ref, nil)
  }

  public static func != (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return !(lhs == rhs)
  }

  public static func === (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx && JSValueIsStrictEqual(lhs.ctx.globalContextRef, lhs.ref, rhs.ref)
  }

  public static func !== (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return !(lhs === rhs)
  }
}
