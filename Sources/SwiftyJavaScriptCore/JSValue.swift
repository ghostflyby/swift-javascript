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
