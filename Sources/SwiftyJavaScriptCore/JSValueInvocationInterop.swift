extension JSValue {
  public static func == (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx
      && JavaScriptCoreBackendDriver.valueEquals(lhs.ref, rhs.ref, in: lhs.ctx)
  }

  public static func != (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return !(lhs == rhs)
  }

  public static func === (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return lhs.ctx == rhs.ctx
      && JavaScriptCoreBackendDriver.valueStrictEquals(lhs.ref, rhs.ref, in: lhs.ctx)
  }

  public static func !== (lhs: borrowing JSValue, rhs: borrowing JSValue) -> Bool {
    return !(lhs === rhs)
  }
}

extension JSValue {
  @inline(__always)
  private func callInternal(
    thisValueHandle: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    .from(
      handleResult: JavaScriptCoreBackendDriver.callFunctionHandle(
        valueHandle(in: context),
        this: thisValueHandle,
        arguments: arguments,
        in: context.driverContextHandle
      ))
  }

  @inline(__always)
  private func constructInternal(
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    .from(
      handleResult: JavaScriptCoreBackendDriver.constructHandle(
        valueHandle(in: context),
        arguments: arguments,
        in: context.driverContextHandle
      ))
  }

  @inline(__always)
  private func encodedArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> [JSValueHandle<JavaScriptCoreEngine>] {
    var values: [JSValueHandle<JavaScriptCoreEngine>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded = (try? argument.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
      values.append(encoded.valueHandle(in: context))
    }

    repeat appendArgument(each arguments)
    return values
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
    callInternal(
      thisValueHandle: nil, arguments: encodedArguments(repeat each arguments, in: context),
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
    callInternal(thisValueHandle: thisValue.valueHandle(in: context), arguments: [], in: context)
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
    callInternal(
      thisValueHandle: thisValue.valueHandle(in: context),
      arguments: encodedArguments(repeat each arguments, in: context),
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
    constructInternal(arguments: encodedArguments(repeat each arguments, in: context), in: context)
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
    invokeMethodInternal(
      name.string,
      arguments: encodedArguments(repeat each arguments, in: context),
      in: context
    )
  }

  private func invokeMethodInternal(
    _ name: String,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    switch JSResult.from(
      handleResult: JavaScriptCoreBackendDriver.getStringPropertyHandle(
        name,
        on: valueHandle(in: context),
        in: context.driverContextHandle
      ))
    {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return .from(
        handleResult: JavaScriptCoreBackendDriver.callFunctionHandle(
          method.valueHandle(in: context),
          this: valueHandle(in: context),
          arguments: arguments,
          in: context.driverContextHandle
        ))
    }
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
    .from(
      handleResult: JavaScriptCoreBackendDriver.toObjectHandle(
        valueHandle(in: context),
        in: context.driverContextHandle
      ))
  }

  public func isArray(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isArray(in: callbackContext)
    }
  }

  public func isArray(in context: borrowing JSInstantContext) -> Bool {
    return JavaScriptCoreBackendDriver.isArrayHandle(
      valueHandle(in: context),
      in: context.driverContextHandle
    ) ?? false
  }

  public func isDate(in context: isolated JSContext = #isolation) -> Bool {
    context.withInstantContext { callbackContext in
      isDate(in: callbackContext)
    }
  }

  public func isDate(in context: borrowing JSInstantContext) -> Bool {
    return JavaScriptCoreBackendDriver.isDateHandle(
      valueHandle(in: context),
      in: context.driverContextHandle
    ) ?? false
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
    return JavaScriptCoreBackendDriver.isInstanceOfHandle(
      valueHandle(in: context),
      constructor: constructor.valueHandle(in: context),
      in: context.driverContextHandle
    ) ?? false
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
    let encoded = (try? value.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
    let didSet = JavaScriptCoreBackendDriver.setStringPropertyHandle(
      key.string,
      on: valueHandle(in: context),
      to: encoded.valueHandle(in: context),
      in: context.driverContextHandle,
      attributes: attributes.hostMemberAttributes
    )
    guard didSet else {
      return .exception(JSValue(undefinedIn: context))
    }

    return .from(
      handleResult: JavaScriptCoreBackendDriver.getStringPropertyHandle(
        key.string,
        on: valueHandle(in: context),
        in: context.driverContextHandle
      ))
  }
}
