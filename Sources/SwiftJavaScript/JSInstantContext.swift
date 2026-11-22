import Synchronization

// MARK: - Scope stack infrastructure

/// LIFO stack of scope frames for a single context. Frames are the scope
/// cores pushed by scope entry (`JSInstantContext.init`, `JSScope.open`)
/// and popped on scope exit; a frame's arena is shared with the scope
/// object that pushed it.
internal final class ScopeStack<E: JSEngineRuntimeDriver>: @unchecked Sendable {
  private var frames: [ScopeFrame<E>] = []

  func push(_ frame: ScopeFrame<E>) { frames.append(frame) }
  @discardableResult
  func pop() -> ScopeFrame<E>? { frames.popLast() }
  var top: ScopeFrame<E>? { frames.last }
  /// Stack bottom = the context default scope (design §3.6). In a bare
  /// context with no `JSContext` host this is simply the outermost open
  /// explicit scope.
  var bottom: ScopeFrame<E>? { frames.first }
  var isEmpty: Bool { frames.isEmpty }
}

/// Non-generic mutex-backed storage for the per-engine registry below
/// (static stored properties are not supported in generic types).
private enum ScopeStackStorage {
  final class State: @unchecked Sendable {
    var stacks: [AnyHashable: Any] = [:]
  }

  static let state = Mutex(State())
}

/// Per-engine registry of per-context scope stacks, keyed by context handle.
/// Scope addressing lives on the context, not the thread: execution is
/// serialized by each VM's dedicated executor, so a context's stack is only
/// mutated by its JS thread in practice; the mutex guards the registry
/// structure itself against cross-thread structural access. There is
/// deliberately no process-wide "current context": the top of a context's
/// own stack is the only notion of current. Context handles of different
/// engines are distinct `AnyHashable` keys, so the shared storage cannot
/// mix stacks across engines.
internal enum ScopeStackRegistry<E: JSEngineRuntimeDriver> {

  static func push<R: JSScopeRooting>(
    _ core: ScopeCore<E, R>,
    for context: E.ContextHandle
  ) {
    ScopeStackStorage.state.withLock {
      let key = AnyHashable(context)
      let stack = ($0.stacks[key] as? ScopeStack<E>) ?? ScopeStack()
      stack.push(core.frame)
      $0.stacks[key] = stack
    }
  }

  @discardableResult
  static func pop(for context: E.ContextHandle) -> ScopeFrame<E>? {
    ScopeStackStorage.state.withLock {
      let key = AnyHashable(context)
      guard let stack = $0.stacks[key] as? ScopeStack<E> else { return nil }
      let popped = stack.pop()
      if stack.isEmpty {
        $0.stacks.removeValue(forKey: key)
      }
      return popped
    }
  }

  /// The topmost open scope of a context, if any. Engine results from value
  /// operations are tracked on it.
  static func top(of context: E.ContextHandle) -> ScopeFrame<E>? {
    ScopeStackStorage.state.withLock {
      $0.stacks[AnyHashable(context)] as? ScopeStack<E>
    }?.top
  }

  /// The bottom frame of a context's scope stack: the context default scope
  /// for values that outlive a synchronous scope window (design §3.6/§3.7).
  /// Value-producing operations bridge their engine results onto this frame
  /// because a `JSValue` no longer owns its reference (§3.2).
  static func defaultFrame(for context: E.ContextHandle) -> ScopeFrame<E>? {
    ScopeStackStorage.state.withLock {
      $0.stacks[AnyHashable(context)] as? ScopeStack<E>
    }?.bottom
  }
}

// MARK: - JSCallbackReturn

/// Callback-exit handoff (temporary / persistent / exception).
///
/// §7.2 decision (Stage 3): every form carries a **borrowed** handle whose
/// backing reference is owned by a scope arena (or by the engine's argument
/// frame for callback arguments). The trampoline gives the engine its own
/// reference (QuickJS: `JS_DupValue`; JSC: GC-managed, no reference action)
/// instead of receiving a transferred `OwnedValueHandle`.
///
/// Rationale: the earlier owned handoff existed to compensate for
/// `JSValue.deinit` releasing its reference before the trampoline borrowed
/// it (the ASan-verified error-coder use-after-free). With `JSValue`
/// re-defined as a non-owning local value, the borrow is anchored by the
/// arena — for `persistent` that is the context default scope, which
/// outlives the callback by construction — so no cross-frame ownership
/// transfer is needed. Carrying `OwnedValueHandle` here would create a
/// second ownership path in addition to the arena, which the trampoline
/// would have to settle separately.
public struct JSCallbackReturn<E: JSEngineValueTypes>: ~Copyable {
  package let handle: JSValueHandle<E>
  /// Semantic marker only: trampolines treat all three states uniformly
  /// (borrow + engine-side duplicate) and never read this flag. Anchoring
  /// depends on the value's owning arena — the context default scope for
  /// context-factory values, the callback scope for class-bridge values —
  /// not on this marker.
  package let isPersistent: Bool
  package let isException: Bool

  init(temporary handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = false
  }

  init(persistent value: borrowing JSValue<E>) {
    self.handle = value.borrowHandle()
    self.isPersistent = true
    self.isException = false
  }

  init(exception handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = true
  }
}

// MARK: - JSInstantContext

// MARK: - Value arena

/// Slots per arena chunk (file scope: generic types cannot have static
/// stored properties).
private let scopeArenaChunkCapacity = 32

/// A chunk of owned value handles stored in raw pointer memory. `Array`
/// cannot hold `~Copyable` elements and a `~Copyable` stored property of a
/// class cannot be moved out (consumption would leave the instance's
/// memory uninitialized), so elements live in `UnsafeMutablePointer`
/// storage where `move()` is a legal consuming read.
private final class ScopeArenaChunk<Owned: JSOwnedValueManualReferenceCountedHandle & ~Copyable>:
  @unchecked Sendable
{
  let storage: UnsafeMutablePointer<Owned>
  var count = 0
  let capacity: Int
  let next: ScopeArenaChunk<Owned>?

  init(capacity: Int, next: ScopeArenaChunk<Owned>?) {
    self.capacity = capacity
    self.next = next
    self.storage = UnsafeMutablePointer<Owned>.allocate(capacity: capacity)
  }

  var isFull: Bool { count == capacity }
  var isEmpty: Bool { count == 0 }

  func push(_ handle: consuming Owned) {
    storage.advanced(by: count).initialize(to: handle)
    count += 1
  }

  func matches(at index: Int, _ identity: (borrowing Owned) -> Bool) -> Bool {
    identity(storage.advanced(by: index).pointee)
  }

  func popLast() -> Owned? {
    guard count > 0 else { return nil }
    count -= 1
    return storage.advanced(by: count).move()
  }

  /// Vacate slot `index` (consuming its element out) and re-initialize it
  /// with `last`, keeping the occupied prefix of the chunk contiguous.
  /// Returns the vacated element; settling its reference is the caller's
  /// concern.
  func replaceSlot(at index: Int, with last: consuming Owned) -> Owned {
    let vacated = storage.advanced(by: index).move()
    storage.advanced(by: index).initialize(to: last)
    return vacated
  }

  deinit {
    if count > 0 {
      storage.deinitialize(count: count)
    }
    storage.deallocate()
  }
}

/// The scope's release ledger. Elements are owned creation results; drain
/// releases every element still present. Values promoted via `persist` are
/// removed at promotion time (identity match, first hit), so no separate
/// "removed" membership structure exists — the chunk stack is the single
/// source of truth (equivalent structure to the former created+removed
/// pair, replacing the Set membership check with a linear scan).
private final class ScopeArena<Owned: JSOwnedValueManualReferenceCountedHandle & ~Copyable>:
  @unchecked Sendable
{
  private var head: ScopeArenaChunk<Owned>? = nil

  func push(_ handle: consuming Owned) {
    if head?.isFull ?? true {
      head = ScopeArenaChunk<Owned>(capacity: scopeArenaChunkCapacity, next: head)
    }
    head!.push(handle)
  }

  /// Pop the most recently pushed element (consuming move), or `nil` when
  /// the arena is empty. Empty head chunks are retired as they drain.
  func popLast() -> Owned? {
    while let chunk = head, chunk.isEmpty {
      head = chunk.next
    }
    guard let chunk = head else { return nil }
    return chunk.popLast()
  }

  /// Whether any element matches `identity`. Non-destructive counterpart of
  /// `removeFirst`, used to avoid anchoring a value twice when it already
  /// lives in the queried arena.
  func contains(matching identity: (borrowing Owned) -> Bool) -> Bool {
    var current = head
    while let chunk = current {
      for index in 0..<chunk.count where chunk.matches(at: index, identity) {
        return true
      }
      current = chunk.next
    }
    return false
  }

  /// Remove the first element matching `identity` and hand its owned
  /// reference back to the caller, which settles it (release or adopt).
  /// The hole is filled with the arena's last element so every chunk's
  /// occupied prefix stays contiguous.
  func removeFirst(matching identity: (borrowing Owned) -> Bool) -> Owned? {
    // Retire empty head chunks first: a previous removal may have emptied
    // the head chunk without retiring it (retirement runs lazily inside
    // `popLast`). Otherwise a match at a deeper chunk's last element would
    // wrongly take the else-branch, `popLast` would pop the matched element
    // itself, and `replaceSlot` would `move()` from the just-vacated
    // (uninitialized) slot.
    while let chunk = head, chunk.isEmpty {
      head = chunk.next
    }
    var current = head
    while let chunk = current {
      for index in 0..<chunk.count where chunk.matches(at: index, identity) {
        if chunk === head && index == chunk.count - 1 {
          // The matched element is the arena's last: popping it alone both
          // vacates and shrinks.
          return chunk.popLast()
        } else {
          let last = popLast()!
          return chunk.replaceSlot(at: index, with: last)
        }
      }
      current = chunk.next
    }
    return nil
  }
}

// MARK: - Shared scope core

/// Compile-time rooting strategy for a scope arena (design §3.7).
///
/// A synchronous scope relies on the engine's implicit root domain: JSC's
/// conservative stack scan keeps values alive while their frame is on the
/// stack, and reference-counted engines already own the creation reference.
/// A heap-resident (default/async) scope has no such implicit domain and
/// must root every arena element explicitly.
internal protocol JSScopeRooting: Sendable {
  static var rootsArenaValues: Bool { get }
}

/// Synchronous scope strategy: arena entries are only bookkeeping.
internal enum JSImplicitStackRoots: JSScopeRooting {
  static var rootsArenaValues: Bool { false }
}

/// Default/async scope strategy: arena entries are explicitly rooted
/// (JSC `JSValueProtect` / `JSValueUnprotect`; identity on refcounted
/// engines, where the creation reference is the root).
internal enum JSExplicitRoots: JSScopeRooting {
  static var rootsArenaValues: Bool { true }
}

/// The arena frame a scope pushes onto its context's scope stack.
///
/// The rooting tag is a runtime projection of `ScopeCore`'s compile-time
/// `Rooting` parameter: frames of different policies share one stack, and
/// every path that settles an arena reference (drain, transfer) must pair
/// the root taken at insert with an unroot on refcounted GC engines.
internal final class ScopeFrame<E: JSEngineRuntimeDriver>: @unchecked Sendable {
  let driverContextHandle: E.ContextHandle
  private let rootsArenaValues: Bool
  private let arena: ScopeArena<E.OwnedValueHandle>

  init(handle: E.ContextHandle, rootsArenaValues: Bool) {
    self.driverContextHandle = handle
    self.rootsArenaValues = rootsArenaValues
    self.arena = ScopeArena()
  }

  /// Track an engine-returned owning handle, taking the explicit root when
  /// this frame's policy requires one.
  func track(_ handle: consuming E.OwnedValueHandle) {
    if rootsArenaValues {
      driverContextHandle.rootOwnedValueHandle(handle)
    }
    arena.push(handle)
  }

  func drain() {
    while let handle = arena.popLast() {
      if rootsArenaValues {
        driverContextHandle.unrootOwnedValueHandle(handle)
      }
      driverContextHandle.releaseCreatedHandle(handle)
    }
  }

  /// Remove the first element matching `identity` and hand its owned
  /// reference back to the caller (which settles it). An explicit frame
  /// unroots the element before the handoff, so the reference is
  /// transferred without a dangling root.
  func takeFirst(matching identity: (borrowing E.OwnedValueHandle) -> Bool)
    -> E.OwnedValueHandle?
  {
    guard let handle = arena.removeFirst(matching: identity) else { return nil }
    if rootsArenaValues {
      driverContextHandle.unrootOwnedValueHandle(handle)
    }
    return handle
  }

  /// Whether this frame's arena holds an owned element with the given
  /// identity.
  func contains(matching identity: (borrowing E.OwnedValueHandle) -> Bool) -> Bool {
    arena.contains(matching: identity)
  }
}

/// The scope's arena bookkeeping plus rooting policy. `Rooting` is a
/// compile-time tag (design §3.7): synchronous scopes use
/// `JSImplicitStackRoots` (zero-cost), the context default scope uses
/// `JSExplicitRoots` (protect-on-add / unprotect-on-drain on JSC).
struct ScopeCore<E: JSEngineRuntimeDriver, Rooting: JSScopeRooting> {
  let driverContextHandle: E.ContextHandle
  let frame: ScopeFrame<E>

  init(handle: E.ContextHandle) {
    self.driverContextHandle = handle
    self.frame = ScopeFrame(
      handle: handle,
      rootsArenaValues: Rooting.rootsArenaValues
    )
  }

  func drain() {
    frame.drain()
  }

  /// Track an engine-returned owning handle (a value-operation result,
  /// adopted from its borrowed form) on this scope's arena so its drain
  /// releases it.
  func track(_ handle: consuming E.OwnedValueHandle) {
    frame.track(handle)
  }

  func makeString(_ value: String) -> JSCallbackValue<E> {
    guard let h = driverContextHandle.makeStringValueHandle(value) else {
      preconditionFailure("makeString failed")
    }
    let borrowed = h.borrowed()
    track(h)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeString(from keyHandle: E.PropertyStringKeyHandle) -> JSCallbackValue<E>
  where E: JSEnginePropertyDriver {
    guard
      let handle = driverContextHandle.makeStringValueHandle(
        fromPropertyStringKey: keyHandle
      )
    else {
      preconditionFailure("makeString(from:) failed")
    }
    let borrowed = handle.borrowed()
    track(handle)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeNumber(_ value: Double) -> JSCallbackValue<E> {
    guard let h = driverContextHandle.makeNumberValueHandle(value) else {
      preconditionFailure("makeNumber failed")
    }
    let borrowed = h.borrowed()
    track(h)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeBoolean(_ value: Bool) -> JSCallbackValue<E> {
    guard let h = driverContextHandle.makeBooleanValueHandle(value) else {
      preconditionFailure("makeBoolean failed")
    }
    let borrowed = h.borrowed()
    track(h)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeNull() -> JSCallbackValue<E> {
    guard let h = driverContextHandle.makeNullValueHandle() else {
      preconditionFailure("makeNull failed")
    }
    let borrowed = h.borrowed()
    track(h)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeUndefined() -> JSCallbackValue<E> {
    guard let h = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("makeUndefined failed")
    }
    let borrowed = h.borrowed()
    track(h)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeSymbol(_ value: String) -> JSCallbackValue<E> {
    guard let h = driverContextHandle.makeSymbolValueHandle(value) else {
      preconditionFailure("makeSymbol failed")
    }
    let borrowed = h.borrowed()
    track(h)
    return JSCallbackValue(handle: borrowed, context: driverContextHandle)
  }

  func makeObject() -> JSResult<JSCallbackValue<E>> {
    guard let r = driverContextHandle.makeObjectResultHandle() else {
      preconditionFailure("makeObject failed")
    }
    switch consume r {
    case .value(let h):
      let borrowed = h.borrowed()
      track(h)
      return .value(JSCallbackValue(handle: borrowed, context: driverContextHandle))
    case .exception(let h):
      let borrowed = h.borrowed()
      track(h)
      return .exception(JSCallbackValue(handle: borrowed, context: driverContextHandle))
    }
  }

  func makeArray() -> JSResult<JSCallbackValue<E>> {
    guard let r = driverContextHandle.makeArrayResultHandle() else {
      preconditionFailure("makeArray failed")
    }
    switch consume r {
    case .value(let h):
      let borrowed = h.borrowed()
      track(h)
      return .value(JSCallbackValue(handle: borrowed, context: driverContextHandle))
    case .exception(let h):
      let borrowed = h.borrowed()
      track(h)
      return .exception(JSCallbackValue(handle: borrowed, context: driverContextHandle))
    }
  }

  /// Bridge an arena-tracked scope value into a `JSValue` view. The arena is
  /// the sole owner of the reference (§3.2); no retain happens here.
  func makeJSValue(_ value: borrowing JSCallbackValue<E>) -> JSValue<E> {
    makeJSValue(for: value.handle)
  }

  func makeJSValue(for handle: E.ValueHandle) -> JSValue<E> {
    JSValue(handleValue: handle, in: driverContextHandle)
  }

  /// Adopt an engine-created result handle (value or exception) into this
  /// scope's arena and bridge it into `JSValue`.
  func trackResult(_ result: JSResult<E.ValueHandle>?) -> JSResult<JSValue<E>> {
    guard let result else {
      preconditionFailure("ScopeCore result bridge unexpectedly returned nil")
    }
    switch consume result {
    case .value(let handle):
      return .value(trackValueHandle(handle))
    case .exception(let handle):
      return .exception(trackValueHandle(handle))
    }
  }

  private func trackValueHandle(_ handle: E.ValueHandle) -> JSValue<E> {
    track(E.OwnedValueHandle.adopting(handle))
    return makeJSValue(for: handle)
  }

  /// Promote a scope value into the context default scope (design §3.6).
  ///
  /// Stage 3 redefinition (§2.3 open item): this is a **creation-reference
  /// transfer**, not a retain + abandon. The owned reference is removed from
  /// the receiver's arena (`takeFirst`, which unroots it under an explicit
  /// source policy) and pushed into the target arena (`track`, which roots it
  /// under an explicit target policy). For arena-owned values nothing is
  /// retained, released, or abandoned:
  ///
  /// - QuickJS: the reference count is unchanged by the move; the target
  ///   drain settles it exactly once — the former +1 leak is gone.
  /// - JSC: the explicit root moves with the value; the target drain
  ///   unprotects exactly once.
  ///
  /// When the value has no owned element in the receiver's arena (e.g. a
  /// borrowed callback argument), the target claims an owned reference
  /// (`claimOwnedValueHandle`: one dup on this fallback path for
  /// reference-counted engines, identity on GC engines) so the target arena
  /// still owns a reference it can settle.
  ///
  /// The default target is the bottom frame of the context scope stack. In a
  /// bare context without a `JSContext` host there is no default scope, so
  /// the bottom (outermost open) frame is the fallback target — in nested
  /// bare scopes that is not necessarily the receiver; the returned view is
  /// valid for that frame's lifetime.
  func persist(_ value: borrowing JSCallbackValue<E>) -> JSValue<E> {
    let target = ScopeStackRegistry<E>.defaultFrame(for: driverContextHandle) ?? frame
    return persist(value, into: target)
  }

  /// Persist into an explicitly chosen scope arena (the default scope is the
  /// common case; a caller may target another live scope).
  func persist(
    _ value: borrowing JSCallbackValue<E>,
    into target: ScopeFrame<E>
  ) -> JSValue<E> {
    let handle = value.handle
    if let owned = frame.takeFirst(matching: { $0.borrowed() == handle }) {
      target.track(owned)
    } else {
      target.track(driverContextHandle.claimOwnedValueHandle(handle))
    }
    return makeJSValue(for: handle)
  }

  func `return`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(temporary: value.handle)
  }

  // MARK: - Default-scope operations (design §3.6)
  //
  // These mirror the actor value factories and route their engine results
  // into the default scope's arena. They are used by `JSContext` only.
  // Synchronous scopes create values on their own arena; promoting one out
  // of the window is `persist`, which now transfers the owned reference
  // (Stage 3) instead of retaining `JSValue`.

  func globalObjectValue() -> JSValue<E> {
    guard let handle = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("ScopeCore.globalObjectValue could not create handle")
    }
    return JSValue(handleValue: handle, in: driverContextHandle)
  }

  func makeFunctionValue(
    named name: String,
    callback: @escaping JSFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    guard
      let handle = driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("ScopeCore.makeFunctionValue could not create handle")
    }
    let borrowed = handle.borrowed()
    track(handle)
    return makeJSValue(for: borrowed)
  }
}

extension ScopeCore where E: JSEnginePropertyDriver {
  /// Global property read whose engine result is tracked on this scope's
  /// arena (default scope) rather than owned by `JSValue`. Exception results
  /// bridge to `undefined`, matching `JSObject.getProperty`.
  func getGlobalPropertyValue(forKey key: StaticString) -> JSValue<E> {
    guard let global = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("ScopeCore.getGlobalPropertyValue could not get global object")
    }
    guard
      let result = driverContextHandle.getStaticStringPropertyHandle(
        key,
        on: global
      )
    else {
      preconditionFailure("ScopeCore.getGlobalPropertyValue returned nil")
    }
    switch consume result {
    case .value(let handle):
      return trackValueHandle(handle)
    case .exception(let handle):
      // Engine results are new references on the exception path too
      // (QuickJS: `JS_GetException` returns +1). This API maps a failed
      // global read to `undefined`, so the exception value is not exposed —
      // settle its reference instead of dropping the handle (which leaked
      // one QuickJS reference per failed read).
      driverContextHandle.releaseCreatedHandle(E.OwnedValueHandle.adopting(handle))
      return makeJSValue(makeUndefined())
    }
  }
}

extension ScopeCore where E: JSEnginePreparedScriptDriver {
  /// Prepared-script evaluation whose engine result is tracked on this
  /// scope's arena (default scope).
  func evaluateScriptValue(
    _ script: borrowing JSPreparedScript<E>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    trackResult(
      driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: driverContextHandle),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }
}

/// Adopt an engine-created owning handle (a creation or value-operation
/// result) into the context default scope arena and return a local view.
///
/// This is the `JSValue`-producing counterpart of `bridgeCallbackResult`:
/// callback values are scoped to the synchronous callback window and are
/// tracked on the current top frame, while `JSValue` results may leave that
/// window and are therefore anchored on the context default scope (§3.6).
package func adoptCreatedValueHandle<E: JSEngineRuntimeDriver>(
  _ handle: E.ValueHandle,
  in context: E.ContextHandle
) -> JSValue<E> {
  guard let target = ScopeStackRegistry<E>.defaultFrame(for: context) else {
    preconditionFailure(
      "JSValue creation requires an open scope (the context default scope)"
    )
  }
  target.track(E.OwnedValueHandle.adopting(handle))
  return JSValue(handleValue: handle, in: context)
}

/// Owned-handle variant of `adoptCreatedValueHandle`: factories that already
/// return the ownership carrier move it straight into the default arena.
package func adoptCreatedOwnedValueHandle<E: JSEngineRuntimeDriver>(
  _ handle: consuming E.OwnedValueHandle,
  in context: E.ContextHandle
) -> JSValue<E> {
  let borrowed = handle.borrowed()
  guard let target = ScopeStackRegistry<E>.defaultFrame(for: context) else {
    preconditionFailure(
      "JSValue creation requires an open scope (the context default scope)"
    )
  }
  target.track(handle)
  return JSValue(handleValue: borrowed, in: context)
}

/// Anchor a borrowed value that must outlive the current synchronous window
/// (e.g. wrapping an existing `JSValue` into a longer-lived `JSArrayBuffer`).
///
/// The default scope claims an owned reference for the identity (dup on
/// reference-counted engines, identity on GC engines, where the explicit
/// root supplied by `track` is the anchor).
package func anchorBorrowedValueHandle<E: JSEngineRuntimeDriver>(
  _ handle: E.ValueHandle,
  in context: E.ContextHandle
) -> JSValue<E> {
  guard let target = ScopeStackRegistry<E>.defaultFrame(for: context) else {
    return JSValue(handleValue: handle, in: context)
  }
  target.track(context.claimOwnedValueHandle(handle))
  return JSValue(handleValue: handle, in: context)
}

/// A callback scope context. Manages scope-stack push/pop on the
/// context-addressed registry (`ScopeStackRegistry`), arena-based value
/// lifecycle, and all value factory methods. Values are released on deinit
/// unless `persist()`ed or returned.
public struct JSInstantContext<E: JSEngineRuntimeDriver>: ~Copyable {
  private var core: ScopeCore<E, JSImplicitStackRoots>

  public var driverContextHandle: E.ContextHandle { core.driverContextHandle }

  /// This scope's arena frame: the source of `persist` transfers and an
  /// explicit `persist(_:into:)` target.
  var scopeFrame: ScopeFrame<E> { core.frame }

  /// Anchor a value that is about to escape a synchronous witness scope.
  ///
  /// Conversion entry points (the `isolated JSContext` overloads) create a
  /// temporary `JSInstantContext` and return its value to the caller. When the
  /// returned view's reference is still owned by that temporary arena (the
  /// host-object bridge shape), it must be claimed into the context default
  /// scope before the witness drains; values already anchored elsewhere
  /// (e.g. `persist`ed into the default scope) are returned as plain views.
  package func anchorEscapingValue(_ value: borrowing JSValue<E>) -> JSValue<E> {
    let handle = value.borrowHandle()
    guard scopeFrame.contains(matching: { $0.borrowed() == handle }) else {
      return JSValue(copying: value)
    }
    return anchorBorrowedValueHandle(handle, in: driverContextHandle)
  }

  @available(*, noasync)
  package init(handle: E.ContextHandle) {
    self.core = ScopeCore<E, JSImplicitStackRoots>(handle: handle)
    ScopeStackRegistry.push(core, for: handle)
  }

  deinit {
    core.drain()
    ScopeStackRegistry<E>.pop(for: driverContextHandle)
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
  package func makeSymbol(_ v: String) -> JSCallbackValue<E> { core.makeSymbol(v) }

  @available(*, noasync)
  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSCallbackValue<E>
  where E: JSEnginePropertyDriver {
    core.makeString(from: key.borrowHandle(in: self))
  }

  @available(*, noasync)
  public func makeObject() -> JSResult<JSCallbackValue<E>> { core.makeObject() }
  @available(*, noasync)
  public func makeArray() -> JSResult<JSCallbackValue<E>> { core.makeArray() }

  // MARK: - Scope operations

  /// Transfer a value created in this scope into the context default scope
  /// (the scope stack bottom) and return a local view. This is a move of the
  /// arena's owned reference — no retain/release/abandon.
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

  @available(*, noasync)
  public func `return`(_ v: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> { core.return(v) }

  /// Throw an arena-backed value. §7.2: the handoff borrows the handle; the
  /// trampoline hands the engine its own reference (QuickJS duplicate) while
  /// the owning arena settles its reference at drain. Works identically for
  /// values created in this callback scope and for persistent values living
  /// in the context default scope.
  @available(*, noasync)
  public func `throw`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(exception: value.handle)
  }

  @available(*, noasync)
  public func returnUndefined() -> JSCallbackReturn<E> {
    guard let h = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("JSInstantContext.returnUndefined could not create handle")
    }
    // Undefined carries no reference to balance (engine immediate / GC
    // singletons), so the owned creation result is unwrapped to its
    // borrowed token without a release.
    return JSCallbackReturn(temporary: h.borrowed())
  }

  @available(*, noasync)
  public func throwUndefined() -> JSCallbackReturn<E> {
    guard let h = driverContextHandle.makeUndefinedValueHandle() else {
      preconditionFailure("JSInstantContext.throwUndefined could not create handle")
    }
    return JSCallbackReturn(exception: h.borrowed())
  }

  // MARK: - Global object

  /// The global object is addressed through a *borrowed* handle (JSC:
  /// `JSContextGetGlobalObject`; QuickJS: the context-owned global),
  /// so the returned local view needs no arena entry.
  @available(*, noasync)
  public func globalObjectValue() -> JSValue<E> {
    guard let handle = driverContextHandle.globalObjectValueHandle() else {
      preconditionFailure("JSInstantContext.globalObjectValue could not create handle")
    }
    return JSValue(handleValue: handle, in: driverContextHandle)
  }

  @available(*, noasync)
  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    body(globalObjectValue())
  }

  @available(*, noasync)
  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: StaticString,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable, E: JSValueConversionEngine {
    withGlobalObject { global in
      global.setProperty(value, forKey: key, with: attributes, in: self)
    }
  }

  @available(*, noasync)
  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: StaticString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) where E: JSValueConversionEngine {
    withGlobalObject { global in
      global.setProperty(value, forKey: key, using: converter, with: attributes, in: self)
    }
  }

  @available(*, noasync)
  public func getGlobalProperty(forKey key: StaticString) -> JSValue<E>
  where E: JSEnginePropertyDriver {
    withGlobalObject { global in
      global.getProperty(forKey: key, in: self)
    }
  }

  @available(*, noasync)
  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: StaticString,
    using converter: C.Type
  ) -> C.SwiftType where E: JSValueConversionEngine {
    withGlobalObject { global in
      global.getProperty(forKey: key, using: converter, in: self)
    }
  }

  @available(*, noasync)
  public func deleteGlobalProperty(forKey key: StaticString)
  where E: JSEnginePropertyDriver {
    withGlobalObject { global in
      global.deleteProperty(forKey: key, in: self)
    }
  }

  @available(*, noasync)
  public func hasGlobalProperty(_ key: StaticString) -> Bool
  where E: JSEnginePropertyDriver {
    withGlobalObject { global in
      global.hasProperty(key, in: self)
    }
  }

  @available(*, noasync)
  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback<E>
  ) where E.Engine == E, E: JSEnginePropertyDriver {
    let function = makeFunction(named: name, callback: callback)
    let key = makePropertyStringKey(name)
    withGlobalObject { global in
      global.setProperty(function, forKey: key, with: attributes, in: self)
    }
  }

  // MARK: - Other operations

  @available(*, noasync)
  public func toBoolean(_ value: borrowing JSValue<E>) -> Bool {
    driverContextHandle.toBooleanForHandle(value.borrowHandle())
  }

  @available(*, noasync)
  public func toNumber(_ value: borrowing JSValue<E>) -> Double {
    driverContextHandle.toNumberForHandle(value.borrowHandle())
  }

  @available(*, noasync)
  public func toString(_ value: borrowing JSValue<E>) -> String {
    driverContextHandle.toStringForHandle(value.borrowHandle()) ?? ""
  }

  // setData/data/makePropertyStringKey/prepareScript are deliberately not
  // `noasync`: they are not scope-bound value operations — context data is
  // scope-independent, and property-string-key / prepared-script handles are
  // Sendable and self-owning, valid beyond the scope window.
  public func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type = K.self) {
    driverContextHandle.contextDataStorageBox()?.setData(value, for: key)
  }

  public func data<K: JSContextDataKey>(for key: K.Type = K.self) -> K.Value? {
    driverContextHandle.contextDataStorageBox()?.data(for: key) ?? K.defaultValue
  }

  public func makePropertyStringKey(_ value: String) -> JSPropertyStringKey<E>
  where E: JSEnginePropertyDriver {
    guard let handle = driverContextHandle.makePropertyStringKeyHandle(value) else {
      preconditionFailure("JSInstantContext.makePropertyStringKey could not create handle")
    }
    return JSPropertyStringKey(handle: handle, context: driverContextHandle)
  }

  public func prepareScript(_ source: String) -> JSPreparedScript<E>
  where E: JSEnginePreparedScriptDriver {
    guard let handle = driverContextHandle.makePreparedScriptHandle(source) else {
      preconditionFailure("JSInstantContext.prepareScript could not create handle")
    }
    return JSPreparedScript(handle: handle, context: driverContextHandle)
  }

  @available(*, noasync)
  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    guard
      let handle = driverContextHandle.makeFunctionValueHandle(
        named: name, callback: callback)
    else {
      preconditionFailure("JSInstantContext.makeFunction could not create handle")
    }
    // The function can escape this synchronous window as a JSValue, so its
    // creation reference is adopted by the context default scope arena.
    return adoptCreatedOwnedValueHandle(handle, in: driverContextHandle)
  }

  @available(*, noasync)
  public func evaluateScript(
    _ script: borrowing JSPreparedScript<E>,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where E: JSEnginePreparedScriptDriver {
    bridgeHandleResult(
      driverContextHandle.evaluatePreparedScriptResultHandle(
        script.borrowHandle(in: self),
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      ), in: driverContextHandle
    )
  }

  @available(*, noasync)
  public func evaluateScript(
    _ script: String,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where E: JSEnginePreparedScriptDriver {
    let prepared = prepareScript(script)
    return evaluateScript(prepared, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }
}

extension JSInstantContext: JSScopeWitness {
  typealias Engine = E
}
