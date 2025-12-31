//
//  File.swift
//  SwiftyJavaScriptCore
//
//  Created by ghostflyby pan on 2025/9/12.
//

import Foundation
import JavaScriptCore.JSValueRef

public protocol JSValueMarshal: ~Copyable, Sendable {
  init(value: borrowing JSValue, in context: isolated JSContext)
  func toJSValue(in context: isolated JSContext) -> JSValue
}

public struct JSValue: ~Copyable, @unchecked Sendable {
  let ref: JSValueRef
  let ctx: JSContextRef

  init(ref: JSValueRef, ctx: JSContextRef) {
    self.ref = ref
    self.ctx = ctx
    JSValueProtect(ctx, ref)
    JSGlobalContextRetain(ctx)
  }

  public init(string value: String, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeString(context.ref, JSStringValue(value).ref)
    self.init(ref: s!, ctx: context.ref)
  }

  public init(string value: borrowing JSString, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeString(context.ref, value.ref)
    self.init(ref: s!, ctx: context.ref)
  }

  public init(number value: Double, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeNumber(context.ref, value)
    self.init(ref: s!, ctx: context.ref)
  }

  public init(number value: some BinaryInteger, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeNumber(context.ref, Double(value))
    self.init(ref: s!, ctx: context.ref)
  }

  public init(boolean value: Bool, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeBoolean(context.ref, value)
    self.init(ref: s!, ctx: context.ref)
  }

  public init(symbol: String, in context: isolated JSContext = #isolation) {
    let s = JSValueMakeSymbol(context.ref, JSStringCreateWithCFString(symbol as CFString))
    self.init(ref: s!, ctx: context.ref)
  }

  public init(nullIn context: isolated JSContext = #isolation) {
    let s = JSValueMakeNull(context.ref)
    self.init(ref: s!, ctx: context.ref)
  }

  public init(undefinedIn context: isolated JSContext = #isolation) {
    let s = JSValueMakeUndefined(context.ref)
    self.init(ref: s!, ctx: context.ref)
  }

  public typealias JSFunctionCallback =
    @Sendable (
      _ context: isolated JSContext, _ function: borrowing JSValue,
      _ this: borrowing JSValue,
      _ arguments: Span<JSValue>, _ exception: inout JSValue
    ) -> JSValue

  public init(
    name: String,
    callback: @escaping JSFunctionCallback,
    in context: isolated JSContext = #isolation,
  ) {
    let s = JSObjectMakeFunctionWithCallback(
      context.ref, JSStringCreateWithCFString(name as CFString),
      { c, f, this, count, args, excption in
        // let context = JSContext(virtualMachine: JSVirtualMachine())
        let function = JSValue(ref: f!, ctx: c!)
        let this = JSValue(ref: this!, ctx: c!)
        let buffer = UnsafeMutableBufferPointer<JSValue>.allocate(capacity: Int(count))
        let args = Span<JSValueRef?>(_unsafeStart: args!, count: Int(count))
        for i in 0..<count {
          let arg = args[i] ?? JSValueMakeNull(c)!
          buffer.initializeElement(at: i, to: JSValue(ref: arg, ctx: c!))
        }
        defer {
          buffer.deinitialize().deallocate()
        }
        let span = buffer.span
        var exceptionValue: JSValue = JSValue(ref: JSValueMakeNull(c), ctx: c!)
        let callback = Unmanaged<Box<JSFunctionCallback>>.fromOpaque(JSObjectGetPrivate(f)!)
          .takeUnretainedValue().value
        let v = context.assumeIsolated { context in
          return JSRefBox(ref: callback(context, function, this, span, &exceptionValue).ref)
        }
        return v.ref
      })
    JSObjectSetPrivate(s, Unmanaged.passRetained(Box(callback)).toOpaque())
    self.init(ref: s!, ctx: context.ref)
  }

  private struct JSRefBox: @unchecked Sendable {
    let ref: JSValueRef
  }

  public init<each A: JSValueMarshal, R: JSValueMarshal>(
    in context: isolated JSContext = #isolation, name: String,
    function: @escaping @Sendable (repeat each A) -> R
  ) {
    let swiftFunction = function
    let count = Mirror(reflecting: (repeat each A).self).children.count
    self.init(name: name) { context, function, this, arguments, exception in
      guard arguments.count == count else {
        return JSValue(undefinedIn: context)
      }
      var idx = 0
      let nextIndex = {
        defer { idx += 1 }
        return idx
      }
      let typedArgs: (repeat each A) =
        (repeat (each A).init(value: arguments[nextIndex()], in: context))
      let r = swiftFunction(repeat each typedArgs)
      return r.toJSValue(in: context)
    }
  }

  deinit {
    JSValueUnprotect(ctx, ref)
    JSGlobalContextRelease(ctx)
  }
}

private class Box<T: ~Copyable> {
  let value: T
  init(_ value: consuming T) {
    self.value = value
  }
}

extension JSValue {
  public static func == (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx && JSValueIsEqual(lhs.ctx, lhs.ref, rhs.ref, nil)
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
