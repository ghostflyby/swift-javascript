/// A callback-scoped JavaScript value that carries its engine context handle.
///
/// `JSCallbackValue` stores the context handle it was created under and
/// addresses every operation (`.toString()`, `.toNumber()`, `.getProperty()`,
/// etc.) through that handle — no ambient (thread- or stack-local) lookup is
/// involved. The context handle is identity only: it does not keep the
/// context alive.
///
/// The value is noncopyable: callback values must not be duplicated or
/// stored beyond the scope whose arena (or the engine's argument frame)
/// backs the underlying handle.
public struct JSCallbackValue<E: JSEngineValueTypes>: ~Copyable {
  /// The raw engine value handle, borrowed from the callback arguments frame
  /// or tracked by the scope arena that created it. The engine owns the
  /// underlying reference; we do NOT retain/release here.
  package let handle: JSValueHandle<E>

  /// The context handle all operations on this value are addressed through.
  package let contextHandle: E.ContextHandle

  package init(handle: JSValueHandle<E>, context: E.ContextHandle) {
    self.handle = handle
    self.contextHandle = context
  }
}

// MARK: - Callback result bridging helper

package func bridgeCallbackResult<E: JSEngineRuntimeDriver>(
  _ result: JSResult<JSValueHandle<E>>?,
  context: E.ContextHandle,
) -> JSResult<JSCallbackValue<E>> {
  guard let result else {
    preconditionFailure("Unexpected nil JSResult in callback bridge")
  }
  // Engine calls return a new owning reference (QuickJS +1); without a
  // release path it would leak on every operation. Adopt the borrowed-form
  // result into the ownership carrier and track it on the context's
  // topmost open scope so its drain releases it.
  guard let scope = ScopeStackRegistry<E>.top(of: context) else {
    preconditionFailure("JSCallbackValue operation used outside any open scope")
  }
  switch result {
  case .value(let handle):
    scope.track(E.OwnedValueHandle.adopting(handle))
    return .value(JSCallbackValue(handle: handle, context: context))
  case .exception(let handle):
    scope.track(E.OwnedValueHandle.adopting(handle))
    return .exception(JSCallbackValue(handle: handle, context: context))
  }
}

// MARK: - Operations
//
// All operations are marked `noasync`: callback values only exist inside
// synchronous scope windows; `noasync` is the compiler-side gate against
// direct calls from async contexts.

extension JSCallbackValue {
  // ---- type query ----

  @available(*, noasync)
  public func type() -> JSType where E: JSEngineRuntimeDriver {
    guard let t = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("Could not determine JS type")
    }
    return t
  }

  // ---- conversions ----

  @available(*, noasync)
  public func toString() -> String where E: JSEngineRuntimeDriver {
    contextHandle.toStringForHandle(handle) ?? ""
  }

  @available(*, noasync)
  public func toNumber() -> Double where E: JSEngineRuntimeDriver {
    contextHandle.toNumberForHandle(handle)
  }

  @available(*, noasync)
  public func toBoolean() -> Bool where E: JSEngineRuntimeDriver {
    contextHandle.toBooleanForHandle(handle)
  }

  // ---- decode (temporary wrapper around JSValueDecodable) ----

  /// `JSValueDecodable`'s requirement still takes `borrowing JSInstantContext`,
  /// so a self-addressed decode must wrap its own context handle in a
  /// temporary scope. That requirement belongs to the conversion user-semantics
  /// layer (TODO §1.1 non-sinking boundary) and is rescheduled with the
  /// `JSValue` local-value unification in Stage 3.
  @available(*, noasync)
  public func decode<T: JSValueDecodable>(as type: T.Type = T.self) -> T
  where E: JSValueConversionEngine {
    let tempValue = JSValue<E>(handleValue: handle, in: contextHandle)
    let result = T(value: tempValue, in: JSInstantContext<E>(handle: contextHandle))
    tempValue.discard()
    return result
  }

  // ---- property access ----

  @available(*, noasync)
  public func getProperty(_ key: StaticString) -> JSResult<JSCallbackValue<E>>
  where E: JSEnginePropertyDriver {
    let r = contextHandle.getStaticStringPropertyHandle(key, on: handle)
    return bridgeCallbackResult(r, context: contextHandle)
  }

  @available(*, noasync)
  public func getProperty(_ key: borrowing JSPropertyStringKey<E>) -> JSResult<JSCallbackValue<E>>
  where E: JSEnginePropertyDriver {
    let r = contextHandle.getPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle
    )
    return bridgeCallbackResult(r, context: contextHandle)
  }

  @available(*, noasync)
  public func setProperty(
    _ value: borrowing JSCallbackValue<E>,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) where E: JSEnginePropertyDriver {
    _ = contextHandle.setStaticStringPropertyHandle(
      key,
      on: handle,
      to: value.handle,
      attributes: attributes.hostMemberAttributes
    )
  }

  @available(*, noasync)
  public func setProperty(
    _ value: borrowing JSCallbackValue<E>,
    forKey key: borrowing JSPropertyStringKey<E>,
    with attributes: JSPropertyAttributes = .none
  ) where E: JSEnginePropertyDriver {
    _ = contextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: contextHandle),
      on: handle,
      to: value.handle,
      attributes: attributes.hostMemberAttributes
    )
  }

  // ---- invocation ----

  @available(*, noasync)
  public func call(
    this: borrowing JSCallbackValue<E>,
    argumentHandles: [JSValueHandle<E>]
  ) -> JSResult<JSCallbackValue<E>> where E: JSEngineInvocationDriver {
    let r = contextHandle.callFunctionHandle(
      handle,
      this: this.handle,
      arguments: argumentHandles
    )
    return bridgeCallbackResult(r, context: contextHandle)
  }

  // ---- type checks ----

  @available(*, noasync)
  public func isArray() -> Bool where E: JSEngineInvocationDriver {
    contextHandle.isArrayHandle(handle) ?? false
  }

  @available(*, noasync)
  public func isDate() -> Bool where E: JSEngineInvocationDriver {
    contextHandle.isDateHandle(handle) ?? false
  }

  @available(*, noasync)
  public func looselyEquals(_ other: borrowing JSCallbackValue<E>) -> Bool
  where E: JSEngineInvocationDriver {
    contextHandle.looselyEqualsHandle(handle, other.handle) ?? false
  }

  @available(*, noasync)
  public func strictlyEquals(_ other: borrowing JSCallbackValue<E>) -> Bool
  where E: JSEngineInvocationDriver {
    contextHandle.strictlyEqualsHandle(handle, other.handle) ?? false
  }
}
