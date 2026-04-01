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
    JavaScriptCoreBackendDriver.valueEquals(ref, other.ref, in: context.globalContextRef)
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
    JavaScriptCoreBackendDriver.valueStrictEquals(ref, other.ref, in: context.globalContextRef)
  }
}

extension JSValue {
  @inline(__always)
  private func callInternal(
    thisValueHandle: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let adapter = context.valueBridgeAdapter
    return adapter.call(
      function: self,
      this: thisValueHandle,
      arguments: arguments,
      in: context
    )
  }

  @inline(__always)
  private func constructInternal(
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let adapter = context.valueBridgeAdapter
    return adapter.construct(
      constructor: self,
      arguments: arguments,
      in: context
    )
  }

  public func call(in context: isolated JSContext = #isolation) -> JSResult {
    context.withInstantContext { callbackContext in
      call(in: callbackContext)
    }
  }

  public func call(in context: borrowing JSInstantContext) -> JSResult {
    callInternal(thisValueHandle: nil, arguments: [], in: context)
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      call(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let adapter = context.valueBridgeAdapter
    return callInternal(
      thisValueHandle: nil,
      arguments: adapter.encodeArguments(repeat each arguments, in: context),
      in: context)
  }

  public func call(
    this thisValue: borrowing JSValue,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      call(this: thisValue, in: callbackContext)
    }
  }

  public func call(
    this thisValue: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let adapter = context.valueBridgeAdapter
    return callInternal(
      thisValueHandle: adapter.valueHandle(for: thisValue, in: context),
      arguments: [],
      in: context
    )
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      call(this: thisValue, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func call<each A: JSValueEncodable>(
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let adapter = context.valueBridgeAdapter
    return callInternal(
      thisValueHandle: adapter.valueHandle(for: thisValue, in: context),
      arguments: adapter.encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  public func construct(in context: isolated JSContext = #isolation) -> JSResult {
    context.withInstantContext { callbackContext in
      construct(in: callbackContext)
    }
  }

  public func construct(in context: borrowing JSInstantContext) -> JSResult {
    constructInternal(arguments: [], in: context)
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult {
    context.withInstantContext { callbackContext in
      construct(arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func construct<each A: JSValueEncodable>(
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    let adapter = context.valueBridgeAdapter
    return constructInternal(
      arguments: adapter.encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: isolated JSContext = #isolation
  ) -> JSResult where Name: ~Copyable {
    context.withInstantContext { callbackContext in
      invokeMethod(name, in: callbackContext)
    }
  }

  public func invokeMethod<Name: JSString>(
    _ name: borrowing Name,
    in context: borrowing JSInstantContext
  ) -> JSResult where Name: ~Copyable {
    invokeMethodInternal(name.string, arguments: [], in: context)
  }

  public func invokeMethod<each A: JSValueEncodable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: isolated JSContext = #isolation
  ) -> JSResult where Name: ~Copyable {
    context.withInstantContext { callbackContext in
      invokeMethod(name, arguments: repeat each arguments, in: callbackContext)
    }
  }

  public func invokeMethod<each A: JSValueEncodable, Name: JSString>(
    _ name: borrowing Name,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult where Name: ~Copyable {
    let adapter = context.valueBridgeAdapter
    return invokeMethodInternal(
      name.string,
      arguments: adapter.encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  private func invokeMethodInternal(
    _ name: String,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    context.valueBridgeAdapter.invokeMethod(name, on: self, arguments: arguments, in: context)
  }

  public func toNumber(in context: isolated JSContext = #isolation) -> Double {
    toDouble(in: context)
  }

  public func toNumber(in context: borrowing JSInstantContext) -> Double {
    toDouble(in: context)
  }

  public func toObject(in context: isolated JSContext = #isolation) -> JSResult {
    context.withInstantContext { callbackContext in
      toObject(in: callbackContext)
    }
  }

  public func toObject(in context: borrowing JSInstantContext) -> JSResult {
    context.valueBridgeAdapter.toObject(self, in: context)
  }

  public func isArray(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isArray(self, in: context)
  }

  public func isDate(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isDate(in: callbackContext)
    }
  }

  public func isDate(in context: borrowing JSInstantContext) -> Bool {
    context.valueBridgeAdapter.isDate(self, in: context)
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
    context.valueBridgeAdapter.isInstanceOf(self, constructor: constructor, in: context)
  }

  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) -> JSResult where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    context.withInstantContext { callbackContext in
      defineProperty(value, forKey: key, with: attributes, in: callbackContext)
    }
  }

  public func defineProperty<Val, Key>(
    _ value: borrowing Val,
    forKey key: borrowing Key,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) -> JSResult where Val: JSValueEncodable, Val: ~Copyable, Key: JSString, Key: ~Copyable {
    let adapter = context.valueBridgeAdapter
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    let didSet = adapter.setStringProperty(
      key.string,
      on: self,
      to: encoded,
      in: context,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(JSValue(undefinedIn: context))
    }

    return adapter.getStringProperty(key.string, on: self, in: context)
  }
}
