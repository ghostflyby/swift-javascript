import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Each operation drives `JSCContextHandle` directly and adopts every
// engine-returned handle onto the passed scope's arena exactly once — the
// exception path included — so the scope drain settles each reference once.
// The `#isolation` forms below adopt onto the context default scope instead;
// both live here because the value type is the engine's.

extension JSCValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    let contextHandle = context.driverContextHandle
    return bridgeJSCValueResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.getIndexPropertyHandle(at: UInt32(index), on: handle),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing JSCPropertyStringKey,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.setIndexPropertyHandle(
      at: UInt32(index),
      on: handle,
      to: value.borrowHandle()
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: handle)
  }

  public func deleteProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: handle) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    ) ?? false
  }

  public func propertyNames(in context: borrowing JSCInstantContext) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: handle) ?? []
  }

  // MARK: Calling and construction

  public func call(
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: nil,
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCValue,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCCallbackValue,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func construct(
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.constructHandle(handle, argumentHandles: arguments.map(\.handle)),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  public func invokeMethod(
    _ name: borrowing JSCPropertyStringKey,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  // MARK: Object conversion and classification

  public func toObject(
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.toObjectHandle(handle),
      in: context
    )
  }

  public func isArray(in context: borrowing JSCInstantContext) -> Bool {
    context.driverContextHandle.isArrayHandle(handle) ?? false
  }

  public func isDate(in context: borrowing JSCInstantContext) -> Bool {
    context.driverContextHandle.isDateHandle(handle) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: borrowing JSCInstantContext) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(handle)
  }

  public func isTypedArray(in context: borrowing JSCInstantContext) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(handle) != nil
  }

  // MARK: Callback-value parameters
  //
  // A callback window's value view is only an identity, so the operations that
  // consume an argument value accept it directly and borrow its handle.

  public func setProperty(
    _ key: StaticString,
    to value: borrowing JSCCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing JSCPropertyStringKey,
    to value: borrowing JSCCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func isInstanceOf(
    _ constructor: borrowing JSCCallbackValue,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }
}

// MARK: - `#isolation` value conveniences
//
// The same operations addressed through the context actor. A requirement
// cannot carry a default argument, so these same-name overloads keep
// `value.getProperty("x")` callable; their results are adopted onto the
// context default scope exactly once (exception included), so they outlive the
// synchronous call instead of draining with a window.

extension JSCValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    let contextHandle = context.driverContextHandle
    return bridgeJSCValueResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.getIndexPropertyHandle(at: UInt32(index), on: handle),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing JSCPropertyStringKey,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing JSCValue,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setIndexPropertyHandle(
      at: UInt32(index),
      on: handle,
      to: value.borrowHandle()
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: handle)
  }

  public func deleteProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: handle) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    ) ?? false
  }

  public func propertyNames(in context: isolated JSCContext = #isolation) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: handle) ?? []
  }

  // MARK: Object conversion and classification

  public func toObject(in context: isolated JSCContext = #isolation) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.toObjectHandle(handle),
      in: context
    )
  }

  public func isArray(in context: isolated JSCContext = #isolation) -> Bool {
    context.driverContextHandle.isArrayHandle(handle) ?? false
  }

  public func isDate(in context: isolated JSCContext = #isolation) -> Bool {
    context.driverContextHandle.isDateHandle(handle) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing JSCValue,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: isolated JSCContext = #isolation) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(handle)
  }

  public func isTypedArray(in context: isolated JSCContext = #isolation) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(handle) != nil
  }

  // MARK: Callback-value parameters

  public func setProperty(
    _ key: StaticString,
    to value: borrowing JSCCallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing JSCPropertyStringKey,
    to value: borrowing JSCCallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func isInstanceOf(
    _ constructor: borrowing JSCCallbackValue,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }
}

// MARK: - `#isolation` call conveniences
//
// The five call operations addressed through the context actor. Results are
// adopted onto the context default scope exactly once (exception included), so
// they outlive the call itself.

extension JSCValue {
  public func call(
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: nil,
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCValue,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCCallbackValue,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func construct(
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      context.driverContextHandle.constructHandle(handle, argumentHandles: arguments.map(\.handle)),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    switch bridgeJSCValueResult(
      context.driverContextHandle.getStaticStringPropertyHandle(name, on: handle),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeJSCValueResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: handle,
          argumentHandles: arguments.map(\.handle)
        ),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing JSCPropertyStringKey,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    switch bridgeJSCValueResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        name.borrowHandle(in: context.driverContextHandle),
        on: handle
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeJSCValueResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: handle,
          argumentHandles: arguments.map(\.handle)
        ),
        in: context
      )
    }
  }
}

// MARK: - Engine-local result bridging
//
// Every value operation drives the JSC driver and adopts its engine-returned
// handle onto the calling arena exactly once — the exception path included.
// The adoption target belongs to the engine, so this helper lives with it (the
// former core bridge is gone).

private func bridgeJSCValueResult(
  _ result: JSResult<JSCValueHandle>?,
  in context: borrowing JSCInstantContext
) -> JSResult<JSCValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
  }
}

private func bridgeJSCValueResult(
  _ result: JSResult<JSCValueHandle>?,
  in context: isolated JSCContext
) -> JSResult<JSCValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)))
  }
}
