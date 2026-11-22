/// A local JavaScript value view (design §3.2).
///
/// `JSValue` is a local value in the V8 `Local<T>` sense: it stores the
/// engine value handle and the context handle it was created under (both
/// Copyable identity tokens) and carries **no ownership**. The underlying
/// engine reference is owned by the scope arena the value was created in or
/// promoted to (`persist` transfers it into the context default scope), so:
///
/// - `deinit` performs no release — "value dragging a dead context" (§2.5
///   P1) is gone;
/// - copying the view (`init(copying:)`) is side-effect free and confers no
///   ownership, which is why `~Copyable` is a structural, not ownership,
///   constraint;
/// - the view is valid for as long as its arena: a synchronous scope
///   (`JSInstantContext`/`JSScope`) for values that stay inside the scope
///   window, or the context default scope for values promoted by `persist`
///   and for value-producing context operations (§3.6).
///
/// `JSValue` intentionally does not retain a context reference; operations
/// take an explicit `in context`/scope parameter.
public struct JSValue<E: JSEngineValueTypes>: ~Copyable {
  /// The engine value handle. Pure identity/borrow token: the reference is
  /// owned by a scope arena, never by this value.
  package let handle: JSValueHandle<E>
  package let contextHandle: E.ContextHandle

  public func borrowHandle() -> JSValueHandle<E> {
    handle
  }

  package init(handleValue: JSValueHandle<E>, in context: E.ContextHandle) {
    self.handle = handleValue
    self.contextHandle = context
  }

  /// Copy another local value's view. No ownership is transferred because
  /// `JSValue` owns nothing.
  package init(copying value: borrowing JSValue<E>) {
    self.init(handleValue: value.handle, in: value.contextHandle)
  }
}
