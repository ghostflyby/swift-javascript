import Foundation

/// Manual scope with explicit open/close. Uses ~Copyable for automatic cleanup
/// on deinit. Must call `open()` before use to push the context scope stack.
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
public struct JSScope<E: JSEngineRuntimeDriver>: ~Copyable {
  private var core: ScopeCore<E>
  private var isOpen = false

  public var driverContextHandle: E.ContextHandle { core.driverContextHandle }

  @available(*, noasync)
  public init(handle: E.ContextHandle) {
    self.core = ScopeCore(handle: handle)
  }

  /// Push the context scope stack and begin arena tracking. Idempotent.
  @available(*, noasync)
  public mutating func open() {
    guard !isOpen else { return }
    ScopeStackRegistry.push(core, for: driverContextHandle)
    isOpen = true
  }

  deinit {
    core.drain()
    if isOpen { ScopeStackRegistry<E>.pop(for: driverContextHandle) }
  }

  // MARK: - Value factories

  @available(*, noasync)
  public func makeString(_ v: String) -> JSCallbackValue<E> { core.makeString(v) }
  @available(*, noasync)
  public func makeNumber(_ v: Double) -> JSCallbackValue<E> { core.makeNumber(v) }
  @available(*, noasync)
  public func makeBoolean(_ v: Bool) -> JSCallbackValue<E> { core.makeBoolean(v) }
  @available(*, noasync)
  public func makeNull() -> JSCallbackValue<E> { core.makeNull() }
  @available(*, noasync)
  public func makeUndefined() -> JSCallbackValue<E> { core.makeUndefined() }

  @available(*, noasync)
  public func makeNumber(_ value: some BinaryInteger) -> JSCallbackValue<E> {
    makeNumber(Double(value))
  }

  @available(*, noasync)
  public func makeSymbol(_ v: String) -> JSCallbackValue<E> { core.makeSymbol(v) }

  @available(*, noasync)
  public func makeObject() -> JSResult<JSCallbackValue<E>> { core.makeObject() }
  @available(*, noasync)
  public func makeArray() -> JSResult<JSCallbackValue<E>> { core.makeArray() }

  // MARK: - Scope operations

  /// Explicit promotion out of the arena: the only exit semantic this scope
  /// provides. Callback-exit semantics live on `JSInstantContext`.
  @available(*, noasync)
  public func persist(_ v: borrowing JSCallbackValue<E>) -> JSValue<E> { core.persist(v) }
}

extension JSScope: JSScopeWitness {
  typealias Engine = E
}
