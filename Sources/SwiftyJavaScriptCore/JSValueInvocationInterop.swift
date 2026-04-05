extension JSValue {
  public func looselyEquals(
    _ other: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      looselyEquals(other, in: callbackContext)
    }
  }

  public func looselyEquals(_ other: borrowing JSValue, in context: borrowing JSInstantContext)
    -> Bool
  {
    context.looselyEquals(self, other)
  }

  public func strictlyEquals(
    _ other: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      strictlyEquals(other, in: callbackContext)
    }
  }

  public func strictlyEquals(_ other: borrowing JSValue, in context: borrowing JSInstantContext)
    -> Bool
  {
    context.strictlyEquals(self, other)
  }
}

extension JSValue {
  public func call(
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      call(in: callbackContext)
    }
  }

  public func call(in context: borrowing JSInstantContext)
    -> JSResult<JSValue>
  {
    context.call(function: self)
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      call(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> {
    context.call(function: self, arguments: repeat each arguments)
  }

  public func call(
    this thisValue: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      call(this: thisValue, in: callbackContext)
    }
  }

  public func call(
    this thisValue: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> {
    context.call(function: self, this: thisValue)
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      call(this: thisValue, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> {
    context.call(
      function: self,
      this: thisValue,
      arguments: repeat each arguments
    )
  }

  public func construct(
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      construct(in: callbackContext)
    }
  }

  public func construct(
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> {
    context.construct(constructor: self)
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      construct(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> {
    context.construct(
      constructor: self,
      arguments: repeat each arguments
    )
  }

  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> where Name: ~Copyable {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> where Name: ~Copyable {
    context.invokeMethod(name.string, on: self)
  }

  public func invokeMethod<each A: JSValueEncodable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> where Name: ~Copyable {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> where Name: ~Copyable {
    context.invokeMethod(
      name.string,
      on: self,
      arguments: repeat each arguments
    )
  }

  public func toNumber(in context: isolated JSContext = #isolation) -> Double {
    toDouble(in: context)
  }

  public func toNumber(in context: borrowing JSInstantContext) -> Double {
    toDouble(in: context)
  }

  public func toObject(
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue> {
    context.withInstantContext { callbackContext in
      toObject(in: callbackContext)
    }
  }

  public func toObject(
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue> {
    context.toObject(self)
  }

  public func isArray(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext) -> Bool {
    context.isArray(self)
  }

  public func isDate(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isDate(in: callbackContext)
    }
  }

  public func isDate(in context: borrowing JSInstantContext) -> Bool {
    context.isDate(self)
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      isInstanceOf(constructor, in: callbackContext)
    }
  }

  public func isInstanceOf(
    _ constructor: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    context.isInstanceOf(self, constructor: constructor)
  }

  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) -> JSResult<JSValue>
  where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    context.withInstantContext { callbackContext in
      defineProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) -> JSResult<JSValue>
  where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    let didSet = context.setStringProperty(
      key.string,
      on: self,
      to: encoded,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(JSValue(undefinedIn: context))
    }

    return context.getStringProperty(key.string, on: self)
  }
}
