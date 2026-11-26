import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Mirror of the JavaScriptCore file: every operation drives `QJSContextHandle`
// directly and adopts each engine-returned handle onto the passed scope's
// arena exactly once — the exception path included. QuickJS hands back a new
// reference (+1) for each result, so adopting it is what the arena drain later
// settles with `JS_FreeValue`; no `JS_DupValue` happens on this path. The
// `#isolation` forms below adopt onto the context default scope instead; both
// live here because the value type is the engine's.

extension QJSValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    let contextHandle = context.driverContextHandle
    return bridgeQJSValueResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.getIndexPropertyHandle(at: UInt32(index), on: handle),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing QJSPropertyStringKey,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing QJSInstantContext
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
    to value: borrowing QJSValue,
    in context: borrowing QJSInstantContext
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
    in context: borrowing QJSInstantContext
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: handle)
  }

  public func deleteProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: handle) ?? false
  }

  public func hasProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    ) ?? false
  }

  public func propertyNames(in context: borrowing QJSInstantContext) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: handle) ?? []
  }

  // MARK: Calling and construction

  public func call(
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: nil,
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSValue,
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSCallbackValue,
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func construct(
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.constructHandle(handle, argumentHandles: arguments.map(\.handle)),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  public func invokeMethod(
    _ name: borrowing QJSPropertyStringKey,
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  // MARK: Object conversion and classification

  public func toObject(
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.toObjectHandle(handle),
      in: context
    )
  }

  public func isArray(in context: borrowing QJSInstantContext) -> Bool {
    context.driverContextHandle.isArrayHandle(handle) ?? false
  }

  public func isDate(in context: borrowing QJSInstantContext) -> Bool {
    context.driverContextHandle.isDateHandle(handle) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: borrowing QJSInstantContext) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(handle)
  }

  public func isTypedArray(in context: borrowing QJSInstantContext) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(handle) != nil
  }

  // MARK: Callback-value parameters
  //
  // A callback window's value view is only an identity, so the operations that
  // consume an argument value accept it directly and borrow its handle.

  public func setProperty(
    _ key: StaticString,
    to value: borrowing QJSCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing QJSPropertyStringKey,
    to value: borrowing QJSCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing QJSInstantContext
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
    _ constructor: borrowing QJSCallbackValue,
    in context: borrowing QJSInstantContext
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

extension QJSValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    let contextHandle = context.driverContextHandle
    return bridgeQJSValueResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.getIndexPropertyHandle(at: UInt32(index), on: handle),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing QJSPropertyStringKey,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated QJSContext = #isolation
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
    to value: borrowing QJSValue,
    in context: isolated QJSContext = #isolation
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
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: handle)
  }

  public func deleteProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: handle) ?? false
  }

  public func hasProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    let contextHandle = context.driverContextHandle
    return contextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    ) ?? false
  }

  public func propertyNames(in context: isolated QJSContext = #isolation) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: handle) ?? []
  }

  // MARK: Object conversion and classification

  public func toObject(in context: isolated QJSContext = #isolation) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.toObjectHandle(handle),
      in: context
    )
  }

  public func isArray(in context: isolated QJSContext = #isolation) -> Bool {
    context.driverContextHandle.isArrayHandle(handle) ?? false
  }

  public func isDate(in context: isolated QJSContext = #isolation) -> Bool {
    context.driverContextHandle.isDateHandle(handle) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing QJSValue,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      handle,
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: isolated QJSContext = #isolation) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(handle)
  }

  public func isTypedArray(in context: isolated QJSContext = #isolation) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(handle) != nil
  }

  // MARK: Callback-value parameters

  public func setProperty(
    _ key: StaticString,
    to value: borrowing QJSCallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing QJSPropertyStringKey,
    to value: borrowing QJSCallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated QJSContext = #isolation
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
    _ constructor: borrowing QJSCallbackValue,
    in context: isolated QJSContext = #isolation
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

extension QJSValue {
  public func call(
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: nil,
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSValue,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSCallbackValue,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        argumentHandles: arguments.map(\.handle)
      ),
      in: context
    )
  }

  public func construct(
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      context.driverContextHandle.constructHandle(handle, argumentHandles: arguments.map(\.handle)),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    switch bridgeQJSValueResult(
      context.driverContextHandle.getStaticStringPropertyHandle(name, on: handle),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeQJSValueResult(
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
    _ name: borrowing QJSPropertyStringKey,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    switch bridgeQJSValueResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        name.borrowHandle(in: context.driverContextHandle),
        on: handle
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeQJSValueResult(
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
// Every value operation drives the QuickJS driver and adopts its engine-returned
// handle onto the calling arena exactly once — the exception path included.
// The adoption target belongs to the engine, so this helper lives with it (the
// former core bridge is gone).

private func bridgeQJSValueResult(
  _ result: JSResult<QJSValueHandle>?,
  in context: borrowing QJSInstantContext
) -> JSResult<QJSValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
  }
}

private func bridgeQJSValueResult(
  _ result: JSResult<QJSValueHandle>?,
  in context: isolated QJSContext
) -> JSResult<QJSValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(QJSOwnedValueHandle.adopting(handle)))
  }
}
