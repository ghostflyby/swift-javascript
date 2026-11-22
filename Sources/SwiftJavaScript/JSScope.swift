import Foundation

/// Manual scope with explicit open/close. Uses ~Copyable for automatic cleanup
/// on deinit. Must call `open()` before use to push TLS.
///
/// 语义最小面:非回调出口语义不提供,对称不是目标。
/// Minimal semantic surface: callback-exit semantics (`throw`/`return`/
/// `returnUndefined`) are not provided on this type; symmetry with
/// `JSInstantContext` is not a goal.
///
///     var scope = JSScope<Engine>(handle: ctx)
///     scope.open()
///     let val = scope.persist(scope.makeString("hello"))
///     // scope auto-closes on deinit
public struct JSScope<E: JSEngine>: ~Copyable {
  private var core: ScopeCore<E>
  private var isOpen = false

  public var driverContextHandle: E.ContextHandle { core.driverContextHandle }

  public init(handle: E.ContextHandle) {
    self.core = ScopeCore(handle: handle)
  }

  /// Push TLS and begin arena tracking. Idempotent.
  public mutating func open() {
    guard !isOpen else { return }
    TLSCallbackStack.push(driverContextHandle)
    isOpen = true
  }

  deinit {
    core.drain()
    if isOpen { TLSCallbackStack.pop(driverContextHandle) }
  }

  // MARK: - Value factories

  public func makeString(_ v: String) -> JSCallbackValue<E> { core.makeString(v) }
  public func makeNumber(_ v: Double) -> JSCallbackValue<E> { core.makeNumber(v) }
  public func makeBoolean(_ v: Bool) -> JSCallbackValue<E> { core.makeBoolean(v) }
  public func makeNull() -> JSCallbackValue<E> { core.makeNull() }
  public func makeUndefined() -> JSCallbackValue<E> { core.makeUndefined() }

  public func makeNumber(_ value: some BinaryInteger) -> JSCallbackValue<E> {
    makeNumber(Double(value))
  }

  public func makeSymbol(_ v: String) -> JSCallbackValue<E> { core.makeSymbol(v) }

  public func makeObject() -> JSResult<JSCallbackValue<E>> { core.makeObject() }
  public func makeArray() -> JSResult<JSCallbackValue<E>> { core.makeArray() }

  // MARK: - Scope operations

  /// Explicit promotion out of the arena: the only exit semantic this scope
  /// provides. Callback-exit semantics live on `JSInstantContext`.
  public func persist(_ v: borrowing JSCallbackValue<E>) -> JSValue<E> { core.persist(v) }
}
