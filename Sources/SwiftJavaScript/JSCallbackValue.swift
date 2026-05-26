/// A callback-scoped JavaScript value that reads engine context from TLS.
///
/// `JSCallbackValue` does not store a context reference. Instead every
/// operation (`.toString()`, `.toNumber()`, `.getProperty()`, etc.) looks up
/// the current callback scope on the thread-local scope stack.
///
public struct JSCallbackValue<E: JSEngine> {
  /// The raw engine value handle, borrowed from the callback arguments frame.
  /// The engine owns the underlying reference; we do NOT retain/release here.
  public let handle: JSValueHandle<E>

  package init(handle: JSValueHandle<E>) {
    self.handle = handle
  }
}

// MARK: - Context resolution

extension JSCallbackValue {
  /// Returns the engine context handle for the current TLS scope,
  internal func resolveContext() -> E.ContextHandle {
    guard let context = TLSCallbackStack.top,
      let handle = context as? E.ContextHandle
    else {
      preconditionFailure(
        "JSCallbackValue<\(E.self)> used outside its callback scope"
      )
    }
    return handle
  }
}

// MARK: - Callback result bridging helper

package func bridgeCallbackResult<E: JSEngine>(
  _ result: JSResult<JSValueHandle<E>>?,
  context: E.ContextHandle,
) -> JSResult<JSCallbackValue<E>> {
  guard let result else {
    preconditionFailure("Unexpected nil JSResult in callback bridge")
  }
  switch result {
  case .value(let handle):
    return .value(JSCallbackValue(handle: handle))
  case .exception(let handle):
    return .exception(JSCallbackValue(handle: handle))
  }
}

// MARK: - Operations

extension JSCallbackValue {
  // ---- type query ----

  public func type() -> JSType {
    let ctx = resolveContext()
    guard let t = E.valueTypeForHandle(handle, in: ctx) else {
      preconditionFailure("Could not determine JS type")
    }
    return t
  }

  // ---- conversions ----

  public func toString() -> String {
    E.toStringForHandle(handle, in: resolveContext()) ?? ""
  }

  public func toNumber() -> Double {
    E.toNumberForHandle(handle, in: resolveContext())
  }

  public func toBoolean() -> Bool {
    E.toBooleanForHandle(handle, in: resolveContext())
  }

  // ---- decode (temporary wrapper around JSValueDecodable) ----

  public func decode<T: JSValueDecodable>(as type: T.Type = T.self) -> T {
    let ctx = resolveContext()
    let tempValue = JSValue<E>(handleValue: handle, in: ctx)
    let result = T(value: tempValue, in: JSInstantContext<E>(handle: ctx))
    tempValue.discard()
    return result
  }

  // ---- property access ----

  public func getProperty(_ key: StaticString) -> JSResult<JSCallbackValue<E>> {
    let ctx = resolveContext()
    let r = E.getStaticStringPropertyHandle(key, on: handle, in: ctx)
    return bridgeCallbackResult(r, context: ctx)
  }

  public func getProperty(_ key: borrowing JSPropertyStringKey<E>) -> JSResult<JSCallbackValue<E>> {
    let ctx = resolveContext()
    let r = E.getPropertyStringKeyHandle(
      key.borrowHandle(in: JSInstantContext<E>(handle: ctx)),
      on: handle,
      in: ctx
    )
    return bridgeCallbackResult(r, context: ctx)
  }

  public func setProperty(
    _ value: borrowing JSCallbackValue<E>,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) {
    let ctx = resolveContext()
    _ = E.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.handle,
      in: ctx,
      attributes: attributes.hostMemberAttributes
    )
  }

  public func setProperty(
    _ value: borrowing JSCallbackValue<E>,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none
  ) {
    let ctx = resolveContext()
    _ = E.setPropertyStringKeyHandle(
      key.borrowHandle(in: JSInstantContext<E>(handle: ctx)),
      on: handle,
      to: value.handle,
      in: ctx,
      attributes: attributes.hostMemberAttributes
    )
  }

  // ---- invocation ----

  public func call(
    this: borrowing JSCallbackValue<E>,
    argumentHandles: [JSValueHandle<E>]
  ) -> JSResult<JSCallbackValue<E>> {
    let ctx = resolveContext()
    let r = E.callFunctionHandle(
      handle,
      this: this.handle,
      arguments: argumentHandles,
      in: ctx
    )
    return bridgeCallbackResult(r, context: ctx)
  }

  // ---- type checks ----

  public func isArray() -> Bool {
    E.isArrayHandle(handle, in: resolveContext()) ?? false
  }

  public func isDate() -> Bool {
    E.isDateHandle(handle, in: resolveContext()) ?? false
  }

  public func looselyEquals(_ other: borrowing JSCallbackValue<E>) -> Bool {
    E.looselyEqualsHandle(handle, other.handle, in: resolveContext()) ?? false
  }

  public func strictlyEquals(_ other: borrowing JSCallbackValue<E>) -> Bool {
    E.strictlyEqualsHandle(handle, other.handle, in: resolveContext()) ?? false
  }
}
