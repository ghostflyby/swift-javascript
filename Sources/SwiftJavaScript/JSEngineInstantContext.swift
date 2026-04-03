/// Engine-agnostic instant context shell.
///
/// Concrete engines provide API surface and bridge behaviors in facade
/// modules via constrained extensions.
public struct JSEngineInstantContext<E: JSEngine>: ~Copyable {
  public let driverContextHandle: E.ContextHandle

  package init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
  }
}

extension JSEngineInstantContext {
  @inline(__always)
  private func valueFromHandle(
    _ handle: JSValueHandle<E>?,
    _ failureMessage: StaticString
  ) -> JSEngineValue<E> {
    guard let handle else {
      preconditionFailure(String(describing: failureMessage))
    }
    return JSEngineValue(storage: JSEngineValueStorage(handle: handle))
  }

  public func makeString(_ value: String) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeStringValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeString could not create handle"
    )
  }

  package func makeSymbol(_ value: String) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeSymbolValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeSymbol could not create handle"
    )
  }

  public func makeNumber(_ value: Double) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeNumberValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeNumber could not create handle"
    )
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSEngineValue<E> {
    makeNumber(Double(value))
  }

  public func makeBoolean(_ value: Bool) -> JSEngineValue<E> {
    valueFromHandle(
      E.makeBooleanValueHandle(value, driverContextHandle),
      "JSEngineInstantContext.makeBoolean could not create handle"
    )
  }

  public func makeNull() -> JSEngineValue<E> {
    valueFromHandle(
      E.makeNullValueHandle(driverContextHandle),
      "JSEngineInstantContext.makeNull could not create handle"
    )
  }

  public func makeUndefined() -> JSEngineValue<E> {
    valueFromHandle(
      E.makeUndefinedValueHandle(driverContextHandle),
      "JSEngineInstantContext.makeUndefined could not create handle"
    )
  }
}
