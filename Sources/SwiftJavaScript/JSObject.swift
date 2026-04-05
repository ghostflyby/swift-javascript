extension JSEngineValue {
  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    _ = E.setStringPropertyHandle(
      key,
      on: valueHandle(),
      to: value.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    forKey key: borrowing JSEngineValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    _ = E.setValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      to: value.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    at index: UInt32,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    _ = E.setIndexPropertyHandle(
      at: index,
      on: valueHandle(),
      to: value.valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    forKey key: borrowing JSEngineValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    at index: UInt32,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    _ = E.setStringPropertyHandle(
      key,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSEngineValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    _ = E.setValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: borrowing JSEngineInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    _ = E.setIndexPropertyHandle(
      at: index,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSEngineValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: isolated JSEngineContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    _ = E.setStringPropertyHandle(
      key,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSEngineValue<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    _ = E.setValuePropertyHandle(
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
    in context: borrowing JSEngineInstantContext<E>
  ) {
    let encoded = (try? converter.tryEncode(value, in: context)) ?? context.makeUndefined()
    _ = E.setIndexPropertyHandle(
      at: index,
      on: valueHandle(),
      to: encoded.valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSEngineValue<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, using: converter, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: String,
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let result: JSResultPayload<JSEngineValue<E>> = bridgeHandleResult(
      E.getStringPropertyHandle(
        key,
        on: valueHandle(),
        in: context.driverContextHandle
      ))
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty(
    forKey key: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let result: JSResultPayload<JSEngineValue<E>> = bridgeHandleResult(
      E.getValuePropertyHandle(
        key.valueHandle(),
        on: valueHandle(),
        in: context.driverContextHandle
      ))
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
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let result: JSResultPayload<JSEngineValue<E>> = bridgeHandleResult(
      E.getIndexPropertyHandle(
        at: index,
        on: valueHandle(),
        in: context.driverContextHandle
      ))
    switch consume result
    {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty(
    forKey key: String,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> JSEngineValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    forKey key: borrowing JSEngineValue<E>,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> JSEngineValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(forKey: key, in: callbackContext)
    }
  }

  public func getProperty(
    at index: UInt32,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> JSEngineValue<E> {
    context.withInstantContext { callbackContext in
      getProperty(at: index, in: callbackContext)
    }
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSEngineValue<E>,
    using converter: C.Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> C.SwiftType {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSEngineValue<E>,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(forKey: key, in: context)
    return converter.decode(value, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> C.SwiftType {
    let value = getProperty(at: index, in: context)
    return converter.decode(value, in: context)
  }

  public func deleteProperty(
    forKey key: String,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    _ = E.deleteStringPropertyHandle(
      key,
      on: valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    _ = E.deleteValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: String,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func deleteProperty(
    forKey key: borrowing JSEngineValue<E>,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      deleteProperty(forKey: key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: String,
    in context: borrowing JSEngineInstantContext<E>
  ) -> Bool {
    E.hasStringPropertyHandle(
      key,
      on: valueHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) -> Bool {
    E.hasValuePropertyHandle(
      key.valueHandle(),
      on: valueHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: String,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      hasProperty(key, in: callbackContext)
    }
  }

  public func hasProperty(
    _ key: borrowing JSEngineValue<E>,
    in context: isolated JSEngineContext<E> = #isolation
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

extension JSEngineValue {
  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty(
    _ value: borrowing JSEngineValue<E>,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    setProperty(value, forKey: key.string, using: converter, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    setProperty(value, forKey: key.string, using: converter, with: attributes, in: context)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    getProperty(forKey: key.string, in: context)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> JSEngineValue<E> {
    getProperty(forKey: key.string, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> C.SwiftType {
    getProperty(forKey: key.string, using: converter, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> C.SwiftType {
    getProperty(forKey: key.string, using: converter, in: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSEngineInstantContext<E>
  ) {
    deleteProperty(forKey: key.string, in: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSEngineContext<E> = #isolation
  ) {
    deleteProperty(forKey: key.string, in: context)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: borrowing JSEngineInstantContext<E>
  ) -> Bool {
    hasProperty(key.string, in: context)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> Bool {
    hasProperty(key.string, in: context)
  }
}
