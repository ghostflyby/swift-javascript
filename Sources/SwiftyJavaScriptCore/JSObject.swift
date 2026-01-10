import JavaScriptCore

extension JSValue {
  public func setProperty<Val: JSValueMarshal>(
    _ value: borrowing Val, forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    JSObjectSetProperty(
      context.globalContextRef, self.ref, key.ref, value.toJSValue(in: context).retainedRef(),
      attributes.rawValue, &error)
  }
  public func setProperty<Val: JSValueMarshal>(
    _ value: borrowing Val, forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    JSObjectSetPropertyForKey(
      context.globalContextRef, self.ref, key.ref, value.toJSValue(in: context).retainedRef(),
      attributes.rawValue, &error)
  }
  public func setProperty<Val: JSValueMarshal>(
    _ value: borrowing Val, at index: UInt32,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    JSObjectSetPropertyAtIndex(
      context.globalContextRef, self.ref, index, value.toJSValue(in: context).retainedRef(), &error
    )
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let result = JSObjectGetProperty(
      context.globalContextRef, self.ref, key.ref, nil)!
    return JSValue(ref: result, ctx: context)
  }

  public func getProperty(
    forKey key: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let result = JSObjectGetPropertyForKey(
      context.globalContextRef, self.ref, key.ref, nil)!
    return JSValue(ref: result, ctx: context)
  }

  public func getProperty(
    at index: UInt32,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let result = JSObjectGetPropertyAtIndex(
      context.globalContextRef, self.ref, index, nil)!
    return JSValue(ref: result, ctx: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    JSObjectDeleteProperty(
      context.globalContextRef, self.ref, key.ref, &error)
  }

  public func deleteProperty(
    forKey key: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    JSObjectDeletePropertyForKey(
      context.globalContextRef, self.ref, key.ref, &error)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    JSObjectHasProperty(
      context.globalContextRef, self.ref, key.ref)
  }

  public func hasProperty(
    _ key: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    var error: JSValueRef?
    return JSObjectHasPropertyForKey(
      context.globalContextRef, self.ref, key.ref, &error)
  }

}

public struct JSPropertyAttributes: Sendable, Hashable, OptionSet {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let none = JSPropertyAttributes(
    rawValue: UInt32(JavaScriptCore.kJSPropertyAttributeNone))
  public static let dontEnum = JSPropertyAttributes(
    rawValue: UInt32(JavaScriptCore.kJSPropertyAttributeDontEnum))
  public static let readOnly = JSPropertyAttributes(
    rawValue: UInt32(JavaScriptCore.kJSPropertyAttributeReadOnly))
  public static let dontDelete = JSPropertyAttributes(
    rawValue: UInt32(JavaScriptCore.kJSPropertyAttributeDontDelete))

}
