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
  @_lifetime(borrow self)
  func bridgeInvocationResult(
    _ handleResult: consuming JSResult<JSValueHandle<E>>?
  ) -> JSResult<JSValue<E>> {
    bridgeHandleResult(handleResult)
  }

  func encodeArguments<each A: JSValueEncodable & Escapable>(
    _ arguments: repeat each A
  ) -> [JSValueHandle<E>] {
    var values: [JSValueHandle<E>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    repeat values.append(encodedArgumentHandle(each arguments))
    return values
  }

  private func encodedArgumentHandle<T: JSValueEncodable & Escapable>(
    _ argument: T
  ) -> JSValueHandle<E> {
    let encoded: JSValue<E>
    do {
      encoded = try argument.tryEncode(in: self)
    } catch {
      encoded = makeUndefined()
    }
    return encoded.retainHandle()
  }

  func releaseArguments(_ arguments: [JSValueHandle<E>]) {
    for argument in arguments {
      _ = argument.releaseReference()
    }
  }

  @_lifetime(borrow self)
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

  @_lifetime(borrow self)
  func call(function: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    call(function: function, this: nil, arguments: [])
  }

  @_lifetime(borrow self)
  func call(
    function: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
    call(function: function, this: nil, arguments: arguments)
  }

  @_lifetime(borrow self)
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

  @_lifetime(borrow self)
  func call<each A: JSValueEncodable & Escapable>(
    function: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
    return call(function: function, arguments: argumentHandles)
  }

  @_lifetime(borrow self)
  func call<each A: JSValueEncodable & Escapable>(
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

  @_lifetime(borrow self)
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

  @_lifetime(borrow self)
  func construct(constructor: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    construct(constructor: constructor, arguments: [])
  }

  @_lifetime(borrow self)
  func construct<each A: JSValueEncodable & Escapable>(
    constructor: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
    return construct(constructor: constructor, arguments: argumentHandles)
  }

  @_lifetime(borrow self)
  func getStringProperty(_ key: String, on object: borrowing JSValue<E>) -> JSResult<
    JSValue<E>
  > {
    bridgeInvocationResult(
      E.getStringPropertyHandle(
        key,
        on: valueHandle(for: object),
        in: driverContextHandle
      ))
  }

  func setStringProperty(
    _ key: String,
    on object: borrowing JSValue<E>,
    to value: borrowing JSValue<E>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    E.setStringPropertyHandle(
      key,
      on: valueHandle(for: object),
      to: valueHandle(for: value),
      in: driverContextHandle,
      attributes: attributes
    )
  }

  @_lifetime(borrow self)
  func invokeMethod(
    _ name: String,
    on object: borrowing JSValue<E>,
    arguments: [JSValueHandle<E>]
  ) -> JSResult<JSValue<E>> {
    switch getStringProperty(name, on: object) {
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

  @_lifetime(borrow self)
  func invokeMethod(_ name: String, on object: borrowing JSValue<E>) -> JSResult<JSValue<E>> {
    invokeMethod(name, on: object, arguments: [])
  }

  @_lifetime(borrow self)
  func invokeMethod<each A: JSValueEncodable & Escapable>(
    _ name: String,
    on object: borrowing JSValue<E>,
    arguments: repeat each A
  ) -> JSResult<JSValue<E>> {
    let argumentHandles = encodeArguments(repeat each arguments)
    defer { releaseArguments(argumentHandles) }
    return invokeMethod(name, on: object, arguments: argumentHandles)
  }

  @_lifetime(borrow self)
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
  @_lifetime(borrow context)
  public func call(in context: borrowing isolated JSContext<E> = #isolation) -> JSResult<JSValue<E>>
  {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(call(in: callbackContext))
  }

  @_lifetime(borrow context)
  public func call(in context: borrowing JSInstantContext<E>) -> JSResult<JSValue<E>> {
    context.call(function: self)
  }

  @_lifetime(borrow context)
  public func call<each A: JSValueEncodable & Escapable>(
    arguments: repeat each A,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(call(arguments: repeat each arguments, in: callbackContext))
  }

  @_lifetime(borrow context)
  public func call<each A: JSValueEncodable & Escapable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.call(function: self, arguments: repeat each arguments)
  }

  @_lifetime(borrow context)
  public func call(
    this thisValue: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(call(this: thisValue, in: callbackContext))
  }

  @_lifetime(borrow context)
  public func call(
    this thisValue: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.call(function: self, this: thisValue)
  }

  @_lifetime(borrow context)
  public func call<each A: JSValueEncodable & Escapable>(
    this thisValue: borrowing JSValue<E>,
    arguments: repeat each A,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(
      call(this: thisValue, arguments: repeat each arguments, in: callbackContext)
    )
  }

  @_lifetime(borrow context)
  public func call<each A: JSValueEncodable & Escapable>(
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

  @_lifetime(borrow context)
  public func construct(
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(construct(in: callbackContext))
  }

  @_lifetime(borrow context)
  public func construct(
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.construct(constructor: self)
  }

  @_lifetime(borrow context)
  public func construct<each A: JSValueEncodable & Escapable>(
    arguments: repeat each A,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(construct(arguments: repeat each arguments, in: callbackContext))
  }

  @_lifetime(borrow context)
  public func construct<each A: JSValueEncodable & Escapable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.construct(
      constructor: self,
      arguments: repeat each arguments
    )
  }

  @_lifetime(borrow context)
  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where Name: ~Copyable {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(invokeMethod(name, in: callbackContext))
  }

  @_lifetime(borrow context)
  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where Name: ~Copyable {
    context.invokeMethod(name.string, on: self)
  }

  @_lifetime(borrow context)
  public func invokeMethod<each A: JSValueEncodable & Escapable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> where Name: ~Copyable {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    )
  }

  @_lifetime(borrow context)
  public func invokeMethod<each A: JSValueEncodable & Escapable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> where Name: ~Copyable {
    context.invokeMethod(
      name.string,
      on: self,
      arguments: repeat each arguments
    )
  }

  public func toNumber(in context: borrowing isolated JSContext<E> = #isolation) -> Double {
    let callbackContext = JSInstantContext<E>(context: context)
    return toDouble(in: callbackContext)
  }

  public func toNumber(in context: borrowing JSInstantContext<E>) -> Double {
    toDouble(in: context)
  }

  @_lifetime(borrow context)
  public func toObject(
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>> {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(toObject(in: callbackContext))
  }

  @_lifetime(borrow context)
  public func toObject(
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>> {
    context.toObject(self)
  }

  public func isArray(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext<E>) -> Bool {
    context.isArray(self)
  }

  public func isDate(in context: borrowing isolated JSContext<E> = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isDate(in: callbackContext)
    }
  }

  public func isDate(in context: borrowing JSInstantContext<E>) -> Bool {
    context.isDate(self)
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue<E>,
    in context: borrowing isolated JSContext<E> = #isolation
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
    in context: borrowing isolated JSContext<E> = #isolation
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
    in context: borrowing isolated JSContext<E> = #isolation
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

  @_lifetime(borrow context)
  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing isolated JSContext<E> = #isolation
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    let callbackContext = JSInstantContext<E>(context: context)
    return retainResult(defineProperty(value, forKey: key, with: attributes, in: callbackContext))
  }

  @_lifetime(borrow context)
  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext<E>
  ) -> JSResult<JSValue<E>>
  where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    let encoded: JSValue<E>
    do {
      encoded = try value.tryEncode(in: context)
    } catch {
      encoded = context.makeUndefined()
    }
    let didSet = context.setStringProperty(
      key.string,
      on: self,
      to: encoded,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(context.makeUndefined())
    }

    return context.getStringProperty(key.string, on: self)
  }
}
