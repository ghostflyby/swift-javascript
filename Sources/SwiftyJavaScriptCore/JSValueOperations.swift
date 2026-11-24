import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Each operation drives `JSCContextHandle` directly and adopts every
// engine-returned handle onto the passed scope's arena exactly once — the
// exception path included — so the scope drain settles each reference once.
// The `#isolation` forms live in core (`JSValueOperations.swift`); this file is
// only the synchronous, explicit-scope surface.

extension JSCValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    let contextHandle = context.driverContextHandle
    return bridgeSurfaceHandleResult(
      contextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: contextHandle),
        on: handle
      ),
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
    arguments: [JSCValueHandle],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(handle, this: nil, arguments: arguments),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCValue,
    arguments: [JSCValueHandle],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        handle,
        this: thisValue.borrowHandle(),
        arguments: arguments
      ),
      in: context
    )
  }

  public func construct(
    arguments: [JSCValueHandle],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.constructHandle(handle, arguments: arguments),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [JSCValueHandle],
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
    arguments: [JSCValueHandle],
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
    bridgeSurfaceHandleResult(
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
}
