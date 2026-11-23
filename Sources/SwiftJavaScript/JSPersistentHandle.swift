/// A persistent, Sendable identity for a JavaScript value bound in a
/// context-side registry (design `docs/PERSISTENT_HANDLE_DESIGN.md`).
///
/// This is the explicit counterpart of the default scope (§7.1): host code
/// keeps the handle, the registry keeps one rooted engine reference, and the
/// handle survives across isolation domains. The handle itself is
/// **identity only** — it exposes no JavaScript operation. Recovering access
/// goes through a scope witness (`JSContext.resolve`,
/// `JSInstantContext.resolve`, `JSScope.resolve`), so the produced local view
/// enters the receiving frame's arena like every other value.
///
/// Lifecycle:
/// - minting takes an independent reference (claim + explicit root, copied
///   from the borrowed value) — it is not `persist`'s transfer;
/// - copying the handle only bumps ARC; the binding is owned by this object;
/// - the last owner's release turns the binding's metadata dead immediately
///   and schedules engine settlement on the VM's serial executor;
/// - `invalidate()` does the same explicitly and is idempotent;
/// - once the owning context is torn down, `resolve` returns `nil` and
///   `invalidate()` is a no-op; neither dangles.
///
/// Strength (design §4.4): v1 bindings are **strong** — while a binding is
/// alive the JavaScript value is not collected. Handle lifetime and JS
/// object collection are two events in a future weak mode, not in this one.
public final class JSPersistentHandle<E: JSEngineRuntimeDriver>: Sendable, Hashable {
  /// `(registryID, slot, generation)` (design §1.3).
  ///
  /// - `registry` answers "which container" (never reused, so a destroyed or
  ///   rebuilt context cannot be confused with its predecessor);
  /// - `slot` answers "which table cell";
  /// - `generation` distinguishes a reused cell from the identity that
  ///   previously occupied it (ABA).
  package struct Identity: Sendable, Hashable {
    package let registry: UInt64
    package let slot: UInt32
    package let generation: UInt32

    package init(registry: UInt64, slot: UInt32, generation: UInt32) {
      self.registry = registry
      self.slot = slot
      self.generation = generation
    }
  }

  package let identity: Identity

  /// Weak by design (§2.6): keeping the registry alive from a handle would
  /// keep the whole context alive and make "container death yields nil"
  /// unreachable.
  private let registryReference: PersistentRegistryReference<E>

  package init(identity: Identity, registry: JSPersistentHandleRegistry<E>) {
    self.identity = identity
    self.registryReference = PersistentRegistryReference(registry)
  }

  /// Invalidate the identity immediately; engine settlement happens on the
  /// next serial executor turn, not synchronously. Idempotent and callable
  /// from any thread.
  ///
  /// - Returns: whether this call ended a still-live binding.
  @discardableResult
  public func invalidate() -> Bool {
    registryReference.value?.release(identity) ?? false
  }

  deinit {
    _ = registryReference.value?.release(identity)
  }

  public static func == (lhs: JSPersistentHandle<E>, rhs: JSPersistentHandle<E>) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}

/// Weak holder for the registry. `@unchecked` covers only this box: the weak
/// reference is assigned once in `init`, read-only afterwards, and ARC's weak
/// load/clear is thread-safe. This keeps `JSPersistentHandle` honestly
/// `Sendable` without an `@unchecked` promise on the public type (design
/// §1.2).
private final class PersistentRegistryReference<E: JSEngineRuntimeDriver>: @unchecked Sendable {
  weak var value: JSPersistentHandleRegistry<E>?

  init(_ value: JSPersistentHandleRegistry<E>) {
    self.value = value
  }
}

// MARK: - Minting and resolving

extension JSContext {
  /// Mint a persistent handle for a value of this context (design §6.4).
  ///
  /// Copy semantics: the source value stays valid for the rest of its scope
  /// window, and the binding takes its own reference. Binding granularity is
  /// context-local (`ContextLocal`), so values from another context are
  /// rejected.
  public func makePersistentHandle(_ value: borrowing JSValue<E>) -> JSPersistentHandle<E> {
    precondition(
      value.contextHandle == driverContextHandle,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    return persistentRegistry.makeHandle(value.borrowHandle())
  }

  /// Resolve a handle into a local view anchored on the context default
  /// scope (design §5.2/§7.2).
  ///
  /// Resolution claims a new owned reference into the default scope arena;
  /// the binding keeps its own root. Repeated actor-side resolution therefore
  /// accumulates in the default scope until the context dies — use a
  /// synchronous scope for bulk resolution (§7.2).
  public func resolve(_ handle: JSPersistentHandle<E>) -> JSValue<E>? {
    guard let borrowed = persistentRegistry.borrowLive(handle.identity) else {
      return nil
    }
    defaultScopeFrame.track(driverContextHandle.claimOwnedValueHandle(borrowed))
    return JSValue(handleValue: borrowed, in: driverContextHandle)
  }
}

extension JSInstantContext {
  /// Mint a persistent handle inside a synchronous callback window.
  ///
  /// Requires a hosted `JSContext` (the registry is reached through the
  /// context data storage box); a bare `JSInstantContext(handle:)` has no
  /// registry and fails here.
  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing JSCallbackValue<E>
  ) -> JSPersistentHandle<E> {
    precondition(
      value.contextHandle == driverContextHandle,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    guard let registry = JSPersistentHandleRegistry<E>.registry(for: driverContextHandle) else {
      preconditionFailure(
        "JSPersistentHandle minting requires a hosted JSContext (no registry installed)"
      )
    }
    return registry.makeHandle(value.handle)
  }

  /// Resolve a handle into a local view anchored on this scope's arena.
  /// Returns `nil` for a dead, foreign, or already-closed binding.
  @available(*, noasync)
  public func resolve(_ handle: JSPersistentHandle<E>) -> JSValue<E>? {
    resolvePersistentHandle(handle, in: self)
  }
}

extension JSScope {
  /// Mint a persistent handle from a manually opened scope.
  @available(*, noasync)
  public func makePersistentHandle(
    _ value: borrowing JSCallbackValue<E>
  ) -> JSPersistentHandle<E> {
    precondition(
      value.contextHandle == driverContextHandle,
      "JSPersistentHandle can only be minted for values of its own context"
    )
    guard let registry = JSPersistentHandleRegistry<E>.registry(for: driverContextHandle) else {
      preconditionFailure(
        "JSPersistentHandle minting requires a hosted JSContext (no registry installed)"
      )
    }
    return registry.makeHandle(value.handle)
  }

  /// Resolve a handle into a local view anchored on this scope's arena.
  @available(*, noasync)
  public func resolve(_ handle: JSPersistentHandle<E>) -> JSValue<E>? {
    resolvePersistentHandle(handle, in: self)
  }
}

/// Shared witness-side resolution algorithm (design §5.2).
///
/// The produced view is a *copy*: the receiving frame claims a fresh owned
/// reference and tracks it, while the binding keeps its root. Both roots are
/// necessary — the binding's keeps the value alive without any scope, the
/// view's keeps it alive for the frame's lifetime (§5.3).
@available(*, noasync)
private func resolvePersistentHandle<E: JSEngineRuntimeDriver, W: JSScopeWitness<E> & ~Copyable>(
  _ handle: JSPersistentHandle<E>,
  in witness: borrowing W
) -> JSValue<E>? {
  guard
    let registry = JSPersistentHandleRegistry<E>.registry(
      for: witness.driverContextHandle)
  else {
    return nil
  }
  guard let borrowed = registry.borrowLive(handle.identity) else { return nil }
  witness.scopeFrame.track(
    witness.driverContextHandle.claimOwnedValueHandle(borrowed))
  return JSValue(handleValue: borrowed, in: witness.driverContextHandle)
}
