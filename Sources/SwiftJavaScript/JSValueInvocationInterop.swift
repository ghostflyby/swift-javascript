extension JSInstantContext {
  @inline(__always)
  func valueHandle(for value: borrowing JSValue<E>) -> JSValueHandle<E> {
    let handle = value.borrowHandle()
    precondition(
      E.isValueHandleCompatibleWithContext(handle, in: driverContextHandle),
      "Cross-VM JSValue operation is not allowed; pass a context from the same JSVirtualMachine"
    )
    return handle
  }

  @inline(__always)
  func bridgeInvocationResult(
    _ handleResult: JSResult<JSValueHandle<E>>?
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(handleResult)
  }

  func encodeArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A
  ) -> [JSValueHandle<E>] {
    var values: [JSValueHandle<E>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded = (try? argument.tryEncode(in: self)) ?? makeUndefined()
      values.append(encoded.retainHandle())
    }

    repeat appendArgument(each arguments)
    return values
  }

  func releaseArguments(_ arguments: [JSValueHandle<E>]) {
    for argument in arguments {
      _ = argument.releaseReference()
    }
  }

  func call(
    function: borrowing JSValue<E>,
    this thisValueHandle: JSValueHandle<E>?,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
    bridgeInvocationResult(
      E.callFunctionHandle(
        valueHandle(for: function),
        this: thisValueHandle,
        arguments: arguments,
        in: driverContextHandle
      ))
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
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
    return call(function: function, arguments: argumentHandles)
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue<E>,
    this thisValue: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
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
    bridgeInvocationResult(
      E.constructHandle(
        valueHandle(for: constructor),
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func construct(constructor: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    construct(constructor: constructor, arguments: [])
  }

  func construct<each A: JSValueEncodable>(
    constructor: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
    return construct(constructor: constructor, arguments: argumentHandles)
  }

  func getProperty(_ key: borrowing JSPropertyStringKey<E>, on object: borrowing JSValue<E>)
    -> JSResult<JSValue<E>>
  {
    bridgeInvocationResult(
      E.getPropertyStringKeyHandle(
        key.borrowHandle(in: self),
        on: valueHandle(for: object),
        in: driverContextHandle
      ))
  }

  func setProperty(
    _ key: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>,
    to value: borrowing JSValue<E>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    E.setPropertyStringKeyHandle(
      key.borrowHandle(in: self),
      on: valueHandle(for: object),
      to: valueHandle(for: value),
      in: driverContextHandle,
      attributes: attributes
    )
  }

  func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
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

  func invokeMethod(_ name: String, on object: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    let key = makePropertyStringKey(name)
    return invokeMethod(key, on: object, arguments: [])
  }

  func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>
  ) -> JSResult<JSValue<E>> {
    invokeMethod(name, on: object, arguments: [])
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: String,
    on object: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let key = makePropertyStringKey(name)
    return invokeMethod(key, on: object, arguments: repeat each arguments)
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: borrowing JSPropertyStringKey<E>,
    on object: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
    return invokeMethod(name, on: object, arguments: argumentHandles)
  }

  func toObject(_ value: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    bridgeInvocationResult(
      E.toObjectHandle(
        valueHandle(for: value),
        in: driverContextHandle
      ))
  }

  func isArray(_ value: borrowing JSValue<E>) -> Bool {
    E.isArrayHandle(valueHandle(for: value), in: driverContextHandle) ?? false
  }

  func isDate(_ value: borrowing JSValue<E>) -> Bool {
    E.isDateHandle(valueHandle(for: value), in: driverContextHandle) ?? false
  }

  func isInstanceOf(
    _ value: borrowing JSValue<E>,
    constructor: borrowing JSValue<E>
  ) -> Bool {
    E.isInstanceOfHandle(
      valueHandle(for: value),
      constructor: valueHandle(for: constructor),
      in: driverContextHandle
    ) ?? false
  }

  func looselyEquals(
    _ lhs: borrowing JSValue<E>,
    _ rhs: borrowing JSValue<E>
  ) -> Bool {
    E.looselyEqualsHandle(
      valueHandle(for: lhs),
      valueHandle(for: rhs),
      in: driverContextHandle
    ) ?? false
  }

  func strictlyEquals(
    _ lhs: borrowing JSValue<E>,
    _ rhs: borrowing JSValue<E>
  ) -> Bool {
    E.strictlyEqualsHandle(
      valueHandle(for: lhs),
      valueHandle(for: rhs),
      in: driverContextHandle
    ) ?? false
  }
}

extension JSValue {
  public func call(in context: isolated JSContext<E> = #isolation) -> JSResult<JSValue<E>> {
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
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      call(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.call(function: self, arguments: repeat each arguments)
  }

  public func call(
    this thisValue: borrowing JSValue<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
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
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      call(this: thisValue, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue<E>,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.call(
      function: self,
      this: thisValue,
      arguments: repeat each arguments
    )
  }

  public func construct(
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
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
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      construct(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.construct(
      constructor: self,
      arguments: repeat each arguments
    )
  }

  public func invokeMethod(
    _ name: String,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod(
    _ name: String,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.invokeMethod(name, on: self)
  }

  public func invokeMethod(
    _ name: borrowing JSPropertyStringKey<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.invokeMethod(name, on: self)
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: String,
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: borrowing JSPropertyStringKey<E>,
    arguments: repeat each A,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: String,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.invokeMethod(name, on: self, arguments: repeat each arguments)
  }

  public func invokeMethod<each A: JSValueEncodable>(
    _ name: borrowing JSPropertyStringKey<E>,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.invokeMethod(name, on: self, arguments: repeat each arguments)
  }

  public func toNumber(in context: isolated JSContext<E> = #isolation) -> Double {
    toDouble(in: context)
  }

  public func toNumber(in context: borrowing JSInstantContext<E>) -> Double {
    toDouble(in: context)
  }

  public func toObject(
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    context.withInstantContext { callbackContext in
      toObject(in: callbackContext)
    }
  }

  public func toObject(
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.toObject(self)
  }

  public func isArray(in context: isolated JSContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext<E>) -> Bool {
    context.isArray(self)
  }

  public func isDate(in context: isolated JSContext<E> = #isolation) -> Bool {
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
  ) -> Bool {
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
  ) -> Bool {
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
  ) -> Bool {
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
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable {
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
  where Val: JSValueEncodable, Val: ~Copyable {
    context.withInstantContext { callbackContext in
      defineProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func defineProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable {
    let propertyStringKey = context.makePropertyStringKey(key)
    return defineProperty(value, forKey: propertyStringKey, with: attributes, in: context)
  }

  public func defineProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? context.makeUndefined()
    let didSet = context.setProperty(
      key,
      on: self,
      to: encoded,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(context.makeUndefined())
    }

    return context.getProperty(key, on: self)
  }
}
