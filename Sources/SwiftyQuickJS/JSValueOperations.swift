import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Mirror of the JavaScriptCore file: every operation drives `QJSContextHandle`
// directly and adopts each engine-returned handle onto the passed scope's
// arena exactly once — the exception path included. QuickJS hands back a new
// reference (+1) for each result, so adopting it is what the arena drain later
// settles with `JS_FreeValue`; no `JS_DupValue` happens on this path.

extension QJSValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: handle),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
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
    arguments: [QJSValueHandle],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(handle, this: nil, arguments: arguments),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSValue,
    arguments: [QJSValueHandle],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
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
    arguments: [QJSValueHandle],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.constructHandle(handle, arguments: arguments),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [QJSValueHandle],
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
    arguments: [QJSValueHandle],
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
    bridgeSurfaceHandleResult(
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
}
