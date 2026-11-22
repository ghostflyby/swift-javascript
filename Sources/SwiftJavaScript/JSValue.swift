/// Minimal JavaScript value mapping.
///
/// `JSValue` intentionally does not retain a context reference.
/// It stores the value handle and the context handle it was created under
/// directly as stored properties (both Copyable identity tokens) and relies
/// on explicit `in context` parameters at operation sites.
public struct JSValue<E: JSEngineValueTypes>: ~Copyable {
  /// The engine value handle. Copying is side-effect free; ownership is
  /// carried by convention until Stage 3 — `deinit` releases the reference.
  /// `nil` marks a taken/discarded value whose reference was handed off,
  /// so its destruction skips the release (generic stored properties are
  /// not trivially destructible, which rules out `discard self`).
  package private(set) var handle: JSValueHandle<E>?
  package let contextHandle: E.ContextHandle

  public func borrowHandle() -> JSValueHandle<E> {
    guard let handle else {
      preconditionFailure("JSValue handle was already taken or discarded")
    }
    return handle
  }

  package init(handleValue: JSValueHandle<E>, in context: E.ContextHandle) {
    self.handle = handleValue
    self.contextHandle = context
  }

  public init(retaining value: borrowing JSValue<E>) {
    self.init(handleValue: value.retainHandle(), in: value.contextHandle)
  }

  /// Adopt another value's convention-owned reference without an extra
  /// retain. Used by inits that delegate through scope factories (`self =`
  /// assignments in initializers are not supported once stored properties
  /// are not trivially destructible).
  package init(taking value: consuming JSValue<E>) {
    let context = value.contextHandle
    self.handle = value.takeHandle()
    self.contextHandle = context
  }

  deinit {
    handle?.releaseReference(in: contextHandle)
  }

  public consuming func discard() {
    self.handle = nil
  }

  public consuming func takeHandle() -> JSValueHandle<E> {
    guard let h = handle else {
      preconditionFailure("JSValue handle was already taken or discarded")
    }
    self.handle = nil
    return h
  }

  public func retainHandle() -> JSValueHandle<E> {
    let h = borrowHandle()
    h.retainReference(in: contextHandle)
    return h
  }
}
