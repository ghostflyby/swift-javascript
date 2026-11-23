import Foundation

/// Manual scope with explicit open/close. Uses ~Copyable for automatic cleanup
/// on deinit.
///
/// 语义最小面:非回调出口语义不提供,对称不是目标。
/// Minimal semantic surface: callback-exit semantics (`throw`/`return`/
/// `returnUndefined`) are not provided on this type; symmetry with
/// `JSInstantContext` is not a goal.
///
/// Construction is context-derived on the public surface:
/// `JSContext.makeScope()` returns an **opened** scope.
///
///     var scope = isolatedContext.makeScope()
///     let val = scope.persist(scope.makeString("hello"))
///     // scope auto-closes on deinit
///
/// `~Sendable` is what makes that factory a thread guarantee: the scope
/// cannot leave the isolation — and therefore the VM thread — it was
/// created in, and its arena drains through engine calls (design §3.5,
/// `docs/PERSISTENT_HANDLE_DESIGN.md`). Code that already holds a context
/// handle inside a synchronous window (callbacks, bare contexts) uses the
/// `package` pair `init(handle:)` + `open()` under the same VM-thread
/// precondition.
public struct JSScope<E: JSEngineRuntimeDriver>: ~Copyable, ~Sendable {
  private var core: ScopeCore<E, JSImplicitStackRoots>
  private var isOpen = false

  public var driverContextHandle: E.ContextHandle { core.driverContextHandle }

  /// This scope's arena frame: the source of `persist` transfers and an
  /// explicit `persist(_:into:)` target.
  var scopeFrame: ScopeFrame<E> { core.frame }

  @available(*, noasync)
  package init(handle: E.ContextHandle) {
    self.core = ScopeCore<E, JSImplicitStackRoots>(handle: handle)
  }

  /// Push the context scope stack and begin arena tracking. Idempotent.
  @available(*, noasync)
  package mutating func open() {
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
  ///
  /// The value's owned reference is transferred into the context default
  /// scope (stack bottom); without a hosted `JSContext` the bottom
  /// (outermost open) frame is the fallback target — in nested bare scopes
  /// that is not necessarily the receiver.
  @available(*, noasync)
  public func persist(_ v: borrowing JSCallbackValue<E>) -> JSValue<E> { core.persist(v) }

  /// Transfer a value into an explicitly chosen scope arena.
  @available(*, noasync)
  public func persist(
    _ v: borrowing JSCallbackValue<E>,
    into target: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    core.persist(v, into: target.scopeFrame)
  }

  @available(*, noasync)
  public func persist(
    _ v: borrowing JSCallbackValue<E>,
    into target: borrowing JSScope<E>
  ) -> JSValue<E> {
    core.persist(v, into: target.scopeFrame)
  }
}

extension JSScope: JSScopeWitness {
  typealias Engine = E
}
