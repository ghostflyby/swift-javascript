extension JSValue where E: JSEnginePropertyDriver {
  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: context),
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.setValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: value.borrowHandle()
    )
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    at index: UInt32,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    let encoded = (try? value.tryEncode(in: context)) ?? context.persist(context.makeUndefined())
    _ = context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    let encoded = (try? value.tryEncode(in: context)) ?? context.persist(context.makeUndefined())
    setProperty(encoded, forKey: key, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    let encoded = (try? value.tryEncode(in: context)) ?? context.persist(context.makeUndefined())
    _ = context.driverContextHandle.setValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    let encoded = (try? value.tryEncode(in: context)) ?? context.persist(context.makeUndefined())
    _ = context.driverContextHandle.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: encoded.borrowHandle()
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSContextEngine & JSValueConversionEngine {
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
  ) where E: JSValueConversionEngine {
    let encoded =
      (try? converter.tryEncode(value, in: context)) ?? context.persist(context.makeUndefined())
    _ = context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where E: JSValueConversionEngine {
    let encoded =
      (try? converter.tryEncode(value, in: context)) ?? context.persist(context.makeUndefined())
    setProperty(encoded, forKey: key, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where E: JSValueConversionEngine {
    let encoded =
      (try? converter.tryEncode(value, in: context)) ?? context.persist(context.makeUndefined())
    _ = context.driverContextHandle.setValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) where E: JSValueConversionEngine {
    let encoded =
      (try? converter.tryEncode(value, in: context)) ?? context.persist(context.makeUndefined())
    _ = context.driverContextHandle.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: encoded.borrowHandle()
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine & JSValueConversionEngine {
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
  ) where E: JSContextEngine & JSValueConversionEngine {
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
  ) where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, using: converter, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: StaticString,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(
        key,
        on: borrowHandle()
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.persist(context.makeUndefined())
    }
  }

  public func getProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: context),
        on: borrowHandle()
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.persist(context.makeUndefined())
    }
  }

  public func getProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      context.driverContextHandle.getValuePropertyHandle(
        key.borrowHandle(),
        on: borrowHandle()
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.persist(context.makeUndefined())
    }
  }

  public func getProperty(
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      context.driverContextHandle.getIndexPropertyHandle(
        at: index,
        on: borrowHandle()
      ), in: context.driverContextHandle)
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.persist(context.makeUndefined())
    }
  }

  public func getProperty(
    forKey key: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    at index: UInt32,
    in context: isolated JSContext<E> = #isolation
  ) -> JSValue<E> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      getProperty(at: index, in: callbackContext)
    }
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType where E: JSValueConversionEngine {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType where E: JSValueConversionEngine {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType where E: JSValueConversionEngine {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType where E: JSValueConversionEngine {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType where E: JSContextEngine & JSValueConversionEngine {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSPropertyStringKey<E>,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType where E: JSContextEngine & JSValueConversionEngine {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType where E: JSContextEngine & JSValueConversionEngine {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType where E: JSContextEngine & JSValueConversionEngine {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func deleteProperty(
    forKey key: StaticString,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.deleteStaticStringPropertyHandle(
      key,
      on: borrowHandle()
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: context),
      on: borrowHandle()
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = context.driverContextHandle.deleteValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle()
    )
  }

  public func deleteProperty(
    forKey key: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func deleteProperty(
    forKey key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func deleteProperty(
    forKey key: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(
      key,
      on: borrowHandle()
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    context.driverContextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: context),
      on: borrowHandle()
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    context.driverContextHandle.hasValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle()
    ) ?? false
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      hasProperty(key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      hasProperty(key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool where E: JSContextEngine {
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
