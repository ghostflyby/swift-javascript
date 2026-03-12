import JavaScriptCore

extension JSValue {
  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    let rawContext = context.driverContext
    _ = JavaScriptCoreBackendDriver.setProperty(
      key.string,
      on: rawValue(in: rawContext),
      to: encoded.rawValue(in: rawContext),
      in: rawContext,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    var error: JSValueRef?
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetPropertyForKey(
      context.globalContextRef, self.ref, key.ref, encoded.retainedRef(),
      attributes.rawValue, &error)
  }

  public func setProperty<Val>(
    _ value: borrowing Val, at index: UInt32,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    var error: JSValueRef?
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetPropertyAtIndex(
      context.globalContextRef, self.ref, index, encoded.retainedRef(), &error
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    setProperty(value, forKey: key, with: attributes, in: callbackContext)
  }
  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    var error: JSValueRef?
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    let encoded =
      (try? value.tryEncode(in: callbackContext)) ?? JSValue(undefinedIn: callbackContext)
    JSObjectSetPropertyForKey(
      context.globalContextRef, self.ref, key.ref, encoded.retainedRef(),
      attributes.rawValue, &error)
  }
  public func setProperty<Val>(
    _ value: borrowing Val, at index: UInt32,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    var error: JSValueRef?
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    let encoded =
      (try? value.tryEncode(in: callbackContext)) ?? JSValue(undefinedIn: callbackContext)
    JSObjectSetPropertyAtIndex(
      context.globalContextRef, self.ref, index, encoded.retainedRef(), &error
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    var error: JSValueRef?
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetProperty(
      context.globalContextRef, self.ref, key.ref,
      encoded.retainedRef(),
      attributes.rawValue,
      &error
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    var error: JSValueRef?
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetPropertyForKey(
      context.globalContextRef, self.ref, key.ref,
      encoded.retainedRef(),
      attributes.rawValue,
      &error
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) {
    var error: JSValueRef?
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetPropertyAtIndex(
      context.globalContextRef, self.ref, index,
      encoded.retainedRef(),
      &error
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetProperty(
      context.globalContextRef, self.ref, key.ref,
      encoded.retainedRef(),
      attributes.rawValue,
      &error
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetPropertyForKey(
      context.globalContextRef, self.ref, key.ref,
      encoded.retainedRef(),
      attributes.rawValue,
      &error
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) {
    var error: JSValueRef?
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    JSObjectSetPropertyAtIndex(
      context.globalContextRef, self.ref, index,
      encoded.retainedRef(),
      &error
    )
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    let rawContext = context.driverContext
    let result = JavaScriptCoreBackendDriver.getProperty(
      key.string,
      on: rawValue(in: rawContext),
      in: rawContext
    )
    switch result {
    case .value(let value):
      return JSValue(rawValue: value)
    case .exception:
      return JSValue(undefinedIn: context)
    }
  }

  public func getProperty(
    forKey key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    let result = JSObjectGetPropertyForKey(
      context.globalContextRef, self.ref, key.ref, nil)!
    return JSValue(ref: result, ctx: context)
  }

  public func getProperty(
    at index: UInt32,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    let result = JSObjectGetPropertyAtIndex(
      context.globalContextRef, self.ref, index, nil)!
    return JSValue(ref: result, ctx: context)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return getProperty(forKey: key, in: callbackContext)
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

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) -> C.SwiftType {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) {
    let rawContext = context.driverContext
    _ = JavaScriptCoreBackendDriver.deleteProperty(
      key.string,
      on: rawValue(in: rawContext),
      in: rawContext
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) {
    var error: JSValueRef?
    JSObjectDeletePropertyForKey(
      context.globalContextRef, self.ref, key.ref, &error)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    deleteProperty(forKey: key, in: callbackContext)
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
    in context: borrowing JSInstantContext
  ) -> Bool {
    let rawContext = context.driverContext
    return JavaScriptCoreBackendDriver.hasProperty(
      key.string,
      on: rawValue(in: rawContext),
      in: rawContext
    )
  }

  public func hasProperty(
    _ key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    var error: JSValueRef?
    return JSObjectHasPropertyForKey(
      context.globalContextRef, self.ref, key.ref, &error)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return hasProperty(key, in: callbackContext)
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

extension JSPropertyAttributes {
  fileprivate var hostMemberAttributes: JSHostMemberAttributes {
    var attributes: JSHostMemberAttributes = .none
    if contains(.readOnly) {
      attributes.insert(.readOnly)
    }
    if contains(.dontEnum) {
      attributes.insert(.dontEnum)
    }
    if contains(.dontDelete) {
      attributes.insert(.dontDelete)
    }
    return attributes
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
