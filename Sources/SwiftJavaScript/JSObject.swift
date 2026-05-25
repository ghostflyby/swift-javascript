extension JSValue {
  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: value.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.setPropertyStringKeyHandle(
      key.borrowHandle(in: context),
      on: borrowHandle(),
      to: value.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.setValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      to: value.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: value.borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    at index: UInt32,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    _ = E.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    setProperty(encoded, forKey: key, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    _ = E.setValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    _ = E.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    _ = E.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    setProperty(encoded, forKey: key, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    _ = E.setValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    _ = E.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, using: converter, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: StaticString,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getStaticStringPropertyHandle(
        key,
        on: borrowHandle(),
        in: context.driverContextHandle
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getPropertyStringKeyHandle(
        key.borrowHandle(in: context),
        on: borrowHandle(),
        in: context.driverContextHandle
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getValuePropertyHandle(
        key.borrowHandle(),
        on: borrowHandle(),
        in: context.driverContextHandle
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty(
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getIndexPropertyHandle(
        at: index,
        on: borrowHandle(),
        in: context.driverContextHandle
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty(
    forKey key: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    at index: UInt32,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(at: index, in: callbackContext)
    }
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func deleteProperty(
    forKey key: StaticString,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.deleteStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.deletePropertyStringKeyHandle(
      key.borrowHandle(in: context),
      on: borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.deleteValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func deleteProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func deleteProperty(
    forKey key: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    E.hasStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    E.hasPropertyStringKeyHandle(
      key.borrowHandle(in: context),
      on: borrowHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    E.hasValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      hasProperty(key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      hasProperty(key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      hasProperty(key, in: callbackContext)
    }
  }
}

extension JSPropertyAttributes {
  public var hostMemberAttributes: JSHostMemberAttributes {
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
  public static let none: JSPropertyAttributes = []
  public static let readOnly = JSPropertyAttributes(rawValue: 1 << 0)
  public static let dontEnum = JSPropertyAttributes(rawValue: 1 << 1)
  public static let dontDelete = JSPropertyAttributes(rawValue: 1 << 2)
}
