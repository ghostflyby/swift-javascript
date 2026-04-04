extension JSValue {
  public func setProperty(
    _ value: borrowing JSValue,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    _ = JavaScriptCoreEngine.setStringPropertyHandle(
      key.string,
      on: valueHandle(),
      to: value.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue,
    forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    _ = JavaScriptCoreEngine.setValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      to: value.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue,
    at index: UInt32,
    in context: borrowing JSInstantContext
  ) {
    _ = JavaScriptCoreEngine.setIndexPropertyHandle(
      at: index,
      on: valueHandle(),
      to: value.valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty(
    _ value: borrowing JSValue,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, forKey: key, with: attributes, in: callbackContext)
  }

  public func setProperty(
    _ value: borrowing JSValue,
    forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, forKey: key, with: attributes, in: callbackContext)
  }

  public func setProperty(
    _ value: borrowing JSValue,
    at index: UInt32,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, at: index, in: callbackContext)
  }

  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    _ = JavaScriptCoreEngine.setStringPropertyHandle(
      key.string,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    _ = JavaScriptCoreEngine.setValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val, at index: UInt32,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    _ = JavaScriptCoreEngine.setIndexPropertyHandle(
      at: index,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, forKey: key, with: attributes, in: callbackContext)
  }
  public func setProperty<Val>(
    _ value: borrowing Val, forKey key: borrowing JSValue,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, forKey: key, with: attributes, in: callbackContext)
  }
  public func setProperty<Val>(
    _ value: borrowing Val, at index: UInt32,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
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
    _ = JavaScriptCoreEngine.setStringPropertyHandle(
      key.string,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    _ = JavaScriptCoreEngine.setValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? JSValue(undefinedIn: context)
    _ = JavaScriptCoreEngine.setIndexPropertyHandle(
      at: index,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    setProperty(value, at: index, using: converter, in: callbackContext)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    switch JSResult.from(
      handleResult: JavaScriptCoreEngine.getStringPropertyHandle(
        key.string,
        on: valueHandle(),
        in: context.driverContextHandle
      ))
    {
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
    switch JSResult.from(
      handleResult: JavaScriptCoreEngine.getValuePropertyHandle(
        key.valueHandle(),
        on: valueHandle(),
        in: context.driverContextHandle
      ))
    {
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
    switch JSResult.from(
      handleResult: JavaScriptCoreEngine.getIndexPropertyHandle(
        at: index,
        on: valueHandle(),
        in: context.driverContextHandle
      ))
    {
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
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    return getProperty(forKey: key, in: callbackContext)
  }

  public func getProperty(
    forKey key: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    return getProperty(forKey: key, in: callbackContext)
  }

  public func getProperty(
    at index: UInt32,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
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
    _ = JavaScriptCoreEngine.deleteStringPropertyHandle(
      key.string,
      on: valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) {
    _ = JavaScriptCoreEngine.deleteValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    deleteProperty(forKey: key, in: callbackContext)
  }

  public func deleteProperty(
    forKey key: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    deleteProperty(forKey: key, in: callbackContext)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> Bool {
    return JavaScriptCoreEngine.hasStringPropertyHandle(
      key.string,
      on: valueHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    return JavaScriptCoreEngine.hasValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
    return hasProperty(key, in: callbackContext)
  }

  public func hasProperty(
    _ key: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    let callbackContext = JSInstantContext(handle: context.driverContextHandle)
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
    rawValue: JavaScriptCoreEngine.propertyAttributeNoneRawValue)
  public static let dontEnum = JSPropertyAttributes(
    rawValue: JavaScriptCoreEngine.propertyAttributeDontEnumRawValue)
  public static let readOnly = JSPropertyAttributes(
    rawValue: JavaScriptCoreEngine.propertyAttributeReadOnlyRawValue)
  public static let dontDelete = JSPropertyAttributes(
    rawValue: JavaScriptCoreEngine.propertyAttributeDontDeleteRawValue)
}
