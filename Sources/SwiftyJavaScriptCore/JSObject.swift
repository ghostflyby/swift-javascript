extension JSValue {
  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    _ = context.setStringProperty(key.string, on: self, to: encoded, attributes: attributes)
  }

  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    _ = context.setValueProperty(key, on: self, to: encoded, attributes: attributes)
  }

  public func setProperty<Val>(
    _ value: borrowing Val, at index: UInt32,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    _ = context.setIndexProperty(at: index, on: self, to: encoded)
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
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    setProperty(value, forKey: key, with: attributes, in: callbackContext)
  }
  public func setProperty<Val>(
    _ value: borrowing Val, at index: UInt32,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    setProperty(value, at: index, in: callbackContext)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    _ = context.setStringProperty(key.string, on: self, to: encoded, attributes: attributes)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    _ = context.setValueProperty(key, on: self, to: encoded, attributes: attributes)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    _ = context.setIndexProperty(at: index, on: self, to: encoded)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    setProperty(value, at: index, using: converter, in: callbackContext)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    switch context.getStringProperty(key.string, on: self) {
    case .value(let value):
      return value
    case .exception:
      return JSValue(undefinedIn: context)
    }
  }

  public func getProperty(
    forKey key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    switch context.getValueProperty(key, on: self) {
    case .value(let value):
      return value
    case .exception:
      return JSValue(undefinedIn: context)
    }
  }

  public func getProperty(
    at index: UInt32,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    switch context.getIndexProperty(at: index, on: self) {
    case .value(let value):
      return value
    case .exception:
      return JSValue(undefinedIn: context)
    }
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
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return getProperty(forKey: key, in: callbackContext)
  }

  public func getProperty(
    at index: UInt32,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return getProperty(at: index, in: callbackContext)
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
    _ = context.deleteStringProperty(key.string, on: self)
  }

  public func deleteProperty(
    forKey key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) {
    _ = context.deleteValueProperty(key, on: self)
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
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    deleteProperty(forKey: key, in: callbackContext)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> Bool {
    return context.hasStringProperty(key.string, on: self)
  }

  public func hasProperty(
    _ key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    return context.hasValueProperty(key, on: self)
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
    let callbackContext = JSInstantContext(ctx: context.globalContextRef)
    return hasProperty(key, in: callbackContext)
  }

}

extension JSPropertyAttributes {
  var hostMemberAttributes: JSHostMemberAttributes {
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

extension JSPropertyAttributes {
  public static let none = JSPropertyAttributes(
    rawValue: JavaScriptCoreBackendDriver.propertyAttributeNoneRawValue)
  public static let dontEnum = JSPropertyAttributes(
    rawValue: JavaScriptCoreBackendDriver.propertyAttributeDontEnumRawValue)
  public static let readOnly = JSPropertyAttributes(
    rawValue: JavaScriptCoreBackendDriver.propertyAttributeReadOnlyRawValue)
  public static let dontDelete = JSPropertyAttributes(
    rawValue: JavaScriptCoreBackendDriver.propertyAttributeDontDeleteRawValue)
}
