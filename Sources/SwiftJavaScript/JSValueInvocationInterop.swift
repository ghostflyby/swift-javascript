extension JSInstantContext where E: JSEngineInvocationDriver {
  @inline(__always)
  func valueHandle(for value: borrowing JSValue<E>) -> JSValueHandle<E> {
    let handle = value.borrowHandle()
    precondition(
      driverContextHandle.isContextCompatibleWith(value.contextHandle),
      "Cross-VM JSValue operation is not allowed; pass a context from the same JSVirtualMachine"
    )
    return handle
  }

  func encodeArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A
  ) -> [JSValueHandle<E>] where E: JSValueConversionEngine {
    var values: [JSValueHandle<E>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded = (try? argument.tryEncode(in: self)) ?? persist(makeUndefined())
      // Encoded values are anchored in the scope arena (default scope for
      // promoted values); the engine call only borrows their identities.
      values.append(encoded.borrowHandle())
    }

    repeat appendArgument(each arguments)
    return values
  }

  func call(
    function: borrowing JSValue<E>,
    this thisValueHandle: JSValueHandle<E>?,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      driverContextHandle.callFunctionHandle(
        valueHandle(for: function),
        this: thisValueHandle,
        arguments: arguments
      ), in: driverContextHandle)
  }

  func call(function: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    call(function: function, this: nil, arguments: [])
  }

  func call(
    function: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
    call(function: function, this: nil, arguments: arguments)
  }

  func call(
    function: borrowing JSValue<E>,
    this thisValue: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>] = []
  ) -> JSResult<JSValue<E>> {
    call(
      function: function,
      this: valueHandle(for: thisValue),
      arguments: arguments
    )
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    let argumentHandles = encodeArguments(repeat each arguments)
    return call(function: function, arguments: argumentHandles)
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue<E>,
    this thisValue: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    let argumentHandles = encodeArguments(repeat each arguments)
    return call(
      function: function,
      this: thisValue,
      arguments: argumentHandles
    )
  }

  func construct(
    constructor: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      driverContextHandle.constructHandle(
        valueHandle(for: constructor),
        arguments: arguments
      ), in: driverContextHandle)
  }

  func construct(constructor: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    construct(constructor: constructor, arguments: [])
  }

  func construct<each A: JSValueEncodable>(
    constructor: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    let argumentHandles = encodeArguments(repeat each arguments)
    return construct(constructor: constructor, arguments: argumentHandles)
  }

  func getProperty(_ key: borrowing JSPropertyStringKey<E>, on object: borrowing JSValue<E>)
    -> JSResult<JSValue<E>>
  where E: JSEnginePropertyDriver {
    bridgeHandleResult(
      driverContextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: self),
        on: valueHandle(for: object)
      ), in: driverContextHandle)
  }

  func getProperty(_ key: StaticString, on object: borrowing JSValue<E>) -> JSResult<JSValue<E>>
  where E: JSEnginePropertyDriver {
    bridgeHandleResult(
      driverContextHandle.getStaticStringPropertyHandle(
        key,
        on: valueHandle(for: object)
      ), in: driverContextHandle)
  }

  func setProperty(
    _ key: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>,
    to value: borrowing JSValue<E>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool where E: JSEnginePropertyDriver {
    driverContextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: self),
      on: valueHandle(for: object),
      to: valueHandle(for: value),
      attributes: attributes
    )
  }

  func setProperty(
    _ key: StaticString,
    on object: borrowing JSValue<E>,
    to value: borrowing JSValue<E>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool where E: JSEnginePropertyDriver {
    driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: valueHandle(for: object),
      to: valueHandle(for: value),
      attributes: attributes
    )
  }

  func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    switch getProperty(name, on: object) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return call(
        function: method,
        this: valueHandle(for: object),
        arguments: arguments
      )
    }
  }

  func invokeMethod(
    _ name: StaticString,
    on object: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    switch getProperty(name, on: object) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return call(
        function: method,
        this: valueHandle(for: object),
        arguments: arguments
      )
    }
  }

  func invokeMethod(_ name: StaticString, on object: borrowing JSValue<E>)
    -> JSResult<JSValue<E>> where E: JSValueConversionEngine
  {
    invokeMethod(name, on: object, arguments: [])
  }

  func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    invokeMethod(name, on: object, arguments: [])
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: StaticString,
    on object: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    let argumentHandles = encodeArguments(repeat each arguments)
    return invokeMethod(name, on: object, arguments: argumentHandles)
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    let argumentHandles = encodeArguments(repeat each arguments)
    return invokeMethod(name, on: object, arguments: argumentHandles)
  }

  func toObject(_ value: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    bridgeHandleResult(
      driverContextHandle.toObjectHandle(
        valueHandle(for: value)
      ), in: driverContextHandle)
  }

  func isArray(_ value: borrowing JSValue<E>) -> Bool {
    driverContextHandle.isArrayHandle(valueHandle(for: value)) ?? false
  }

  func isDate(_ value: borrowing JSValue<E>) -> Bool {
    driverContextHandle.isDateHandle(valueHandle(for: value)) ?? false
  }

  func isInstanceOf(
    _ value: borrowing JSValue<E>,
    constructor: borrowing JSValue<E>
  ) -> Bool {
    driverContextHandle.isInstanceOfHandle(
      valueHandle(for: value),
      constructor: valueHandle(for: constructor)
    ) ?? false
  }

  func looselyEquals(
    _ lhs: borrowing JSValue<E>,
    _ rhs: borrowing JSValue<E>
  ) -> Bool {
    driverContextHandle.looselyEqualsHandle(
      valueHandle(for: lhs),
      valueHandle(for: rhs)
    ) ?? false
  }

  func strictlyEquals(
    _ lhs: borrowing JSValue<E>,
    _ rhs: borrowing JSValue<E>
  ) -> Bool {
    driverContextHandle.strictlyEqualsHandle(
      valueHandle(for: lhs),
      valueHandle(for: rhs)
    ) ?? false
  }
}

extension JSValue where E: JSEngineInvocationDriver {
  public func call(in context: isolated JSContext<E> = #isolation) -> JSResult<JSValue<E>>
  where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      call(in: callbackContext)
    }
  }

  public func call(in context: borrowing JSInstantContext<E>) -> JSResult<JSValue<E>> {
    context.call(function: self)
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      call(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.call(function: self, arguments: repeat each arguments)
  }

  public func call(
    this thisValue: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      call(this: thisValue, in: callbackContext)
    }
  }

  public func call(
    this thisValue: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.call(function: self, this: thisValue)
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue<E>,
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      call(this: thisValue, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue<E>,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.call(
      function: self,
      this: thisValue,
      arguments: repeat each arguments
    )
  }

  public func construct(
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      construct(in: callbackContext)
    }
  }

  public func construct(
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.construct(constructor: self)
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      construct(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.construct(
      constructor: self,
      arguments: repeat each arguments
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod(
    _ name: StaticString,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.invokeMethod(name, on: self)
  }

  public func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.invokeMethod(name, on: self)
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: StaticString,
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: borrowing JSPropertyStringKey<E>,
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: StaticString,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.invokeMethod(name, on: self, arguments: repeat each arguments)
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: borrowing JSPropertyStringKey<E>,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where E: JSValueConversionEngine {
    context.invokeMethod(name, on: self, arguments: repeat each arguments)
  }

  public func toNumber(in context: isolated JSContext<E> = #isolation) -> Double
  where E: JSContextEngine & JSValueConversionEngine {
    toDouble(in: context)
  }

  public func toNumber(in context: borrowing JSInstantContext<E>) -> Double
  where E: JSValueConversionEngine {
    toDouble(in: context)
  }

  public func toObject(
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      toObject(in: callbackContext)
    }
  }

  public func toObject(
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.toObject(self)
  }

  public func isArray(in context: isolated JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext<E>) -> Bool {
    context.isArray(self)
  }

  public func isDate(in context: isolated JSContext<E> = #isolation) -> Bool
  where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      isDate(in: callbackContext)
    }
  }

  public func isDate(in context: borrowing JSInstantContext<E>) -> Bool {
    context.isDate(self)
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      isInstanceOf(constructor, in: callbackContext)
    }
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    context.isInstanceOf(self, constructor: constructor)
  }

  public func looselyEquals(
    _ other: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      looselyEquals(other, in: callbackContext)
    }
  }

  public func looselyEquals(
    _ other: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    context.looselyEquals(self, other)
  }

  public func strictlyEquals(
    _ other: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> Bool where E: JSContextEngine {
    context.withInstantContext { callbackContext in
      strictlyEquals(other, in: callbackContext)
    }
  }

  public func strictlyEquals(
    _ other: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Bool {
    context.strictlyEquals(self, other)
  }

  public func defineProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable, E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      defineProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func defineProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable, E: JSContextEngine & JSValueConversionEngine {
    context.withInstantContext { callbackContext in
      defineProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func defineProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    let encoded = (try? value.tryEncode(in: context)) ?? context.persist(context.makeUndefined())
    let didSet = context.setProperty(
      key,
      on: self,
      to: encoded,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(context.persist(context.makeUndefined()))
    }

    return context.getProperty(key, on: self)
  }

  public func defineProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    let encoded = (try? value.tryEncode(in: context)) ?? context.persist(context.makeUndefined())
    let didSet = context.setProperty(
      key,
      on: self,
      to: encoded,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(context.persist(context.makeUndefined()))
    }

    return context.getProperty(key, on: self)
  }
}
