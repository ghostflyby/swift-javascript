import SwiftJavaScript
import Synchronization

// MARK: - Scope stack infrastructure

/// LIFO stack of scope frames for a single context. Frames are the scope
/// cores pushed by scope entry (`JSCInstantContext.init`, `JSCScope.open`,
/// the engine context's default scope) and popped on scope exit; a frame's
/// arena is shared with the scope object that pushed it.
package final class ScopeStack<ContextHandle: JSContextRuntimeDriver>: @unchecked Sendable {
  private var frames: [ScopeFrame<ContextHandle>] = []
  /// The VM thread of a hosted context (design §0.2.3), or `nil` for a bare
  /// one. Written once by `ScopeStackRegistry.bind`, under the registry
  /// lock like every other access to this object.
  package private(set) var vmThread: VMThread? = nil

  package func push(_ frame: ScopeFrame<ContextHandle>) { frames.append(frame) }
  @discardableResult
  package func pop() -> ScopeFrame<ContextHandle>? { frames.popLast() }
  package var top: ScopeFrame<ContextHandle>? { frames.last }
  /// Stack bottom = the context default scope (design §3.6). In a bare
  /// context with no host `JSContext` actor this is simply the outermost open
  /// explicit scope.
  package var bottom: ScopeFrame<ContextHandle>? { frames.first }
  package var isEmpty: Bool { frames.isEmpty }

  package func bind(_ vmThread: VMThread) {
    self.vmThread = vmThread
  }
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
package enum ScopeStackRegistry<ContextHandle: JSContextRuntimeDriver> {

  package static func push<R: JSScopeRooting>(
    _ core: ScopeCore<ContextHandle, R>,
    for context: ContextHandle
  ) {
    ScopeStackStorage.state.withLock {
      let key = AnyHashable(context)
      let stack = ($0.stacks[key] as? ScopeStack<ContextHandle>) ?? ScopeStack()
      stack.push(core.frame)
      $0.stacks[key] = stack
    }
  }

  @discardableResult
  package static func pop(for context: ContextHandle) -> ScopeFrame<ContextHandle>? {
    ScopeStackStorage.state.withLock {
      let key = AnyHashable(context)
      guard let stack = $0.stacks[key] as? ScopeStack<ContextHandle> else { return nil }
      let popped = stack.pop()
      if stack.isEmpty {
        $0.stacks.removeValue(forKey: key)
      }
      return popped
    }
  }

  /// Bind a hosted context to the VM thread that owns its engine access.
  ///
  /// The binding lives exactly as long as the context's stack entry: it
  /// disappears with the last `pop`, which the host `JSContext` actor's
  /// isolated deinit performs before clearing its data box — so that final
  /// swap runs inline, on the thread the deinit is already guaranteed to run
  /// on.
  package static func bind(_ vmThread: VMThread, for context: ContextHandle) {
    ScopeStackStorage.state.withLock {
      ($0.stacks[AnyHashable(context)] as? ScopeStack<ContextHandle>)?.bind(vmThread)
    }
  }

  package static func vmThread(for context: ContextHandle) -> VMThread? {
    ScopeStackStorage.state.withLock {
      ($0.stacks[AnyHashable(context)] as? ScopeStack<ContextHandle>)?.vmThread
    }
  }

  /// The topmost open scope of a context, if any. Engine results from value
  /// operations are tracked on it.
  package static func top(of context: ContextHandle) -> ScopeFrame<ContextHandle>? {
    ScopeStackStorage.state.withLock {
      $0.stacks[AnyHashable(context)] as? ScopeStack<ContextHandle>
    }?.top
  }

  /// The bottom frame of a context's scope stack: the context default scope
  /// for values that outlive a synchronous scope window (design §3.6/§3.7).
  /// Value-producing operations bridge their engine results onto this frame
  /// because a local value view no longer owns its reference (§3.2).
  package static func defaultFrame(for context: ContextHandle) -> ScopeFrame<ContextHandle>? {
    ScopeStackStorage.state.withLock {
      $0.stacks[AnyHashable(context)] as? ScopeStack<ContextHandle>
    }?.bottom
  }
}

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

/// The arena frame a scope pushes onto its context's scope stack.
///
/// The rooting tag is a runtime projection of `ScopeCore`'s compile-time
/// `Rooting` parameter: frames of different policies share one stack, and
/// every path that settles an arena reference (drain, transfer) must pair
/// the root taken at insert with an unroot on refcounted GC engines.
package final class ScopeFrame<ContextHandle: JSContextRuntimeDriver>: @unchecked Sendable {
  package let driverContextHandle: ContextHandle
  private let rootsArenaValues: Bool
  private let arena: ScopeArena<ContextHandle.OwnedValueHandle>

  package init(handle: ContextHandle, rootsArenaValues: Bool) {
    self.driverContextHandle = handle
    self.rootsArenaValues = rootsArenaValues
    self.arena = ScopeArena()
  }

  /// Track an engine-returned owning handle, taking the explicit root when
  /// this frame's policy requires one.
  package func track(_ handle: consuming ContextHandle.OwnedValueHandle) {
    if rootsArenaValues {
      driverContextHandle.rootOwnedValueHandle(handle)
    }
    arena.push(handle)
  }

  package func drain() {
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
  package func takeFirst(matching identity: (borrowing ContextHandle.OwnedValueHandle) -> Bool)
    -> ContextHandle.OwnedValueHandle?
  {
    guard let handle = arena.removeFirst(matching: identity) else { return nil }
    if rootsArenaValues {
      driverContextHandle.unrootOwnedValueHandle(handle)
    }
    return handle
  }

  /// Whether this frame's arena holds an owned element with the given
  /// identity.
  package func contains(matching identity: (borrowing ContextHandle.OwnedValueHandle) -> Bool)
    -> Bool
  {
    arena.contains(matching: identity)
  }
}

/// The scope's arena bookkeeping plus rooting policy. `Rooting` is a
/// compile-time tag (design §3.7): synchronous scopes use
/// `JSImplicitStackRoots` (zero-cost), the context default scope uses
/// `JSExplicitRoots` (protect-on-add / unprotect-on-drain on JSC).
package struct ScopeCore<ContextHandle: JSContextRuntimeDriver, Rooting: JSScopeRooting> {
  package let driverContextHandle: ContextHandle
  package let frame: ScopeFrame<ContextHandle>

  package init(handle: ContextHandle) {
    self.driverContextHandle = handle
    self.frame = ScopeFrame(
      handle: handle,
      rootsArenaValues: Rooting.rootsArenaValues
    )
  }

  package func drain() {
    frame.drain()
  }

  /// Track an engine-returned owning handle (a value-operation result,
  /// adopted from its borrowed form) on this scope's arena so its drain
  /// releases it.
  package func track(_ handle: consuming ContextHandle.OwnedValueHandle) {
    frame.track(handle)
  }
}

// MARK: - Handle-level ledger primitives

/// Ledger primitives shared by the concrete scopes and contexts.
///
/// They keep the one-track-per-handle contract — adopt tracks the consumed
/// creation reference once, anchor claims then tracks once — and hand back the
/// borrowed token only. Wrapping that token in the engine's own value view is
/// the caller's job (`JSCValue`, `QJSValue`, ...): core never constructs a view.
extension ScopeCore {
  /// Adopt an engine-created owning reference: track it exactly once on this
  /// scope's arena and return the borrowed token a value view is built from.
  package func trackCreatedHandle(
    _ handle: consuming ContextHandle.OwnedValueHandle
  ) -> ContextHandle.ValueHandle {
    let borrowed = handle.borrowed()
    track(handle)
    return borrowed
  }

  /// Claim an owned reference for a borrowed handle that no arena owns yet,
  /// track it exactly once on this scope's arena, and return the same token.
  package func claimAndTrackHandle(
    _ handle: ContextHandle.ValueHandle
  ) -> ContextHandle.ValueHandle {
    track(driverContextHandle.claimOwnedValueHandle(handle))
    return handle
  }

  /// Move the reference behind `handle` out of this scope's arena into the
  /// context default scope (design §3.6): an arena-owned reference is
  /// transferred, any other one is claimed once. A bare context has no default
  /// frame, so the reference then stays on this scope's own frame.
  package func transferToDefaultFrame(_ handle: ContextHandle.ValueHandle) {
    let target = ScopeStackRegistry<ContextHandle>.defaultFrame(for: driverContextHandle) ?? frame
    if let owned = frame.takeFirst(matching: { $0.borrowed() == handle }) {
      target.track(owned)
    } else {
      target.track(driverContextHandle.claimOwnedValueHandle(handle))
    }
  }

  /// Track a created reference on the context default scope: for values meant
  /// to outlive this window, such as function values stored as properties.
  package func trackOnDefaultFrame(_ handle: consuming ContextHandle.OwnedValueHandle) {
    let target = ScopeStackRegistry<ContextHandle>.defaultFrame(for: driverContextHandle) ?? frame
    target.track(handle)
  }
}
