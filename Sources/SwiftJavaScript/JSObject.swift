extension JSValue {
  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.setStringPropertyHandle(
      key,
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
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    at index: UInt32,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    let encoded: JSValue<E>
    do {
      encoded = try value.tryEncode(in: context)
    } catch {
      encoded = context.makeUndefined()
    }
    _ = E.setStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    let encoded: JSValue<E>
    do {
      encoded = try value.tryEncode(in: context)
    } catch {
      encoded = context.makeUndefined()
    }
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
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    let encoded: JSValue<E>
    do {
      encoded = try value.tryEncode(in: context)
    } catch {
      encoded = context.makeUndefined()
    }
    _ = E.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSValue<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    at index: UInt32,
    in context: borrowing isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    let encoded: JSValue<E>
    do {
      encoded = try converter.tryEncode(value, in: context)
    } catch {
      encoded = context.makeUndefined()
    }
    _ = E.setStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    let encoded: JSValue<E>
    do {
      encoded = try converter.tryEncode(value, in: context)
    } catch {
      encoded = context.makeUndefined()
    }
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
    let encoded: JSValue<E>
    do {
      encoded = try converter.tryEncode(value, in: context)
    } catch {
      encoded = context.makeUndefined()
    }
    _ = E.setIndexPropertyHandle(
      at: index,
      on: borrowHandle(),
      to: encoded.borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
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
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, forKey: key, using: converter, with: attributes, in: callbackContext)
    }
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    context.withInstantContext { callbackContext in
      setProperty(value, at: index, using: converter, in: callbackContext)
    }
  }

  @_lifetime(borrow context)
  public func getProperty(
    forKey key: String,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getStringPropertyHandle(
        key,
        on: borrowHandle(),
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

  @_lifetime(borrow context)
  public func getProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getValuePropertyHandle(
        key.borrowHandle(),
        on: borrowHandle(),
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

  @_lifetime(borrow context)
  public func getProperty(
    at index: UInt32,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getIndexPropertyHandle(
        at: index,
        on: borrowHandle(),
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

  @_lifetime(borrow context)
  public func getProperty(
    forKey key: String,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getStringPropertyHandle(
        key,
        on: borrowHandle(),
        in: context.driverContextHandle
      ))
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  @_lifetime(borrow context)
  public func getProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getValuePropertyHandle(
        key.borrowHandle(),
        on: borrowHandle(),
        in: context.driverContextHandle
      ))
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  @_lifetime(borrow context)
  public func getProperty(
    at index: UInt32,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getIndexPropertyHandle(
        at: index,
        on: borrowHandle(),
        in: context.driverContextHandle
      ))
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: String,
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
    forKey key: String,
    using converter: C.Type,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let callbackContext = JSInstantContext<E>(context: context)
    return getProperty(forKey: key, using: converter, in: callbackContext)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing JSValue<E>,
    using converter: C.Type,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let callbackContext = JSInstantContext<E>(context: context)
    return getProperty(forKey: key, using: converter, in: callbackContext)
  }

  public func getProperty<C: JSValueDecoder>(
    at index: UInt32,
    using converter: C.Type,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let callbackContext = JSInstantContext<E>(context: context)
    return getProperty(at: index, using: converter, in: callbackContext)
  }

  public func deleteProperty(
    forKey key: String,
    in context: borrowing JSInstantContext<E>
  ) {
    _ = E.deleteStringPropertyHandle(
      key,
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
    forKey key: String,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    _ = E.deleteStringPropertyHandle(
      key,
      on: borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func deleteProperty(
    forKey key: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    _ = E.deleteValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func hasProperty(
    _ key: String,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    E.hasStringPropertyHandle(
      key,
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
    _ key: String,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> Bool {
    E.hasStringPropertyHandle(
      key,
      on: borrowHandle(),
      in: context.driverContextHandle
    ) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> Bool {
    E.hasValuePropertyHandle(
      key.borrowHandle(),
      on: borrowHandle(),
      in: context.driverContextHandle
    ) ?? false
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

extension JSValue {
  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty(
    _ value: borrowing JSValue<E>,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    _ = E.setStringPropertyHandle(
      key.string,
      on: borrowHandle(),
      to: value.borrowHandle(),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable, Val: ~Escapable {
    let callbackContext = JSInstantContext<E>(context: context)
    setProperty(value, forKey: key.string, with: attributes, in: callbackContext)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) {
    setProperty(value, forKey: key.string, using: converter, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    let callbackContext = JSInstantContext<E>(context: context)
    setProperty(value, forKey: key.string, using: converter, with: attributes, in: callbackContext)
  }

  @_lifetime(borrow context)
  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    getProperty(forKey: key.string, in: context)
  }

  @_lifetime(borrow context)
  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getStringPropertyHandle(
        key.string,
        on: borrowHandle(),
        in: context.driverContextHandle
      ))
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      return context.makeUndefined()
    }
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    getProperty(forKey: key.string, using: converter, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    let callbackContext = JSInstantContext<E>(context: context)
    return getProperty(forKey: key.string, using: converter, in: callbackContext)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext<E>
  ) {
    deleteProperty(forKey: key.string, in: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: borrowing isolated JSContext<E> = #isolation
  ) {
    _ = E.deleteStringPropertyHandle(
      key.string,
      on: borrowHandle(),
      in: context.driverContextHandle
    )
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    hasProperty(key.string, in: context)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> Bool {
    E.hasStringPropertyHandle(
      key.string,
      on: borrowHandle(),
      in: context.driverContextHandle
    ) ?? false
  }
}
