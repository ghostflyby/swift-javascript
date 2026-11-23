import Synchronization

// MARK: - Cleanup scheduling

/// Scheduler face used by the persistent-binding registry to run settlement
/// on the VM's dedicated serial executor (design §2.4 option b).
///
/// Cleanup closures and actor jobs share one OS thread, so "the payload is
/// only touched on the VM thread" (§3.5) holds by construction. A stopped
/// executor drops late closures: every binding was already settled inline by
/// `close()` before the executor's owner shuts the thread down.
package protocol JSPersistentCleanupScheduler: Sendable {
  func schedulePersistentCleanup(_ body: @escaping @Sendable () -> Void)
}

// MARK: - Registry identity

/// Process-wide registry identifier (design §1.3): monotonically increasing,
/// never reused, so "wrong container" and "container rebuilt" are a single
/// integer comparison instead of an engine-address ABA check.
private let persistentHandleRegistryIDCounter = Atomic<UInt64>(0)

/// Slots per registry chunk, aligned with the scope arena's chunk capacity
/// (32). Chunking exists because `Array` cannot hold `~Copyable` payloads.
private let persistentHandleSlotChunkCapacity = 32

/// Slot state machine (design §3.4).
///
/// `settling` is load-bearing: it marks "payload moved out of the slot,
/// engine settlement not yet recorded", so a late pump, `close()`, or a
/// `release` re-entering from an engine finalizer cannot move the payload a
/// second time.
private enum PersistentSlotState: UInt8 {
  case free = 0
  case live = 1
  case pendingRelease = 2
  case settling = 3
}

// MARK: - Slot storage

/// A chunk of owned value handles stored in raw pointer memory.
///
/// Mirrors `ScopeArenaChunk` (`JSInstantContext.swift`): `Array` cannot hold
/// `~Copyable` elements and a `~Copyable` stored property of a class cannot be
/// moved out, so payloads live in `UnsafeMutablePointer` storage where
/// `move()` is a legal consuming read. Slots are addressed by global slot
/// index; the chunk holds the per-slot generation and state.
private final class PersistentHandleSlotChunk<
  Owned: JSOwnedValueManualReferenceCountedHandle & ~Copyable
>: @unchecked Sendable {
  let capacity: Int
  let payloads: UnsafeMutablePointer<Owned>
  var generations: [UInt32]
  var states: [UInt8]

  init(capacity: Int) {
    self.capacity = capacity
    self.payloads = UnsafeMutablePointer<Owned>.allocate(capacity: capacity)
    self.generations = Array(repeating: 0, count: capacity)
    self.states = Array(
      repeating: PersistentSlotState.free.rawValue, count: capacity)
  }

  deinit {
    // Reaching deinit without `close()` is a programming error (asserted by
    // the registry). Release builds deliberately do not touch the engine from
    // an arbitrary thread (design §4.1); deinitialize whatever is still
    // constructed so Swift-level payload bits are not silently dropped, and
    // let the engine references leak.
    for index in 0..<capacity {
      let state = states[index]
      if state == PersistentSlotState.live.rawValue
        || state == PersistentSlotState.pendingRelease.rawValue
      {
        payloads.advanced(by: index).deinitialize(count: 1)
      }
    }
    payloads.deallocate()
  }
}

/// Working item for the settlement loop: the slot metadata (copyable) plus
/// the payload moved out of the slot. `Payload` is `~Copyable`; the item is
/// produced inside `Mutex.withLock` and consumed outside it, so no engine
/// call ever happens under the mutex (design §3.5).
private struct PersistentSettlement<
  Payload: JSOwnedValueManualReferenceCountedHandle & ~Copyable
>: ~Copyable {
  let chunk: PersistentHandleSlotChunk<Payload>
  let index: Int
  let slot: UInt32
  var payload: Payload
}

// MARK: - Registry state

private struct PersistentHandleRegistryState<
  Owned: JSOwnedValueManualReferenceCountedHandle & ~Copyable
>: @unchecked Sendable {
  var closed = false
  var pumpScheduled = false
  var chunks: [PersistentHandleSlotChunk<Owned>] = []
  /// Slots whose payload was settled; reusable until their generation is
  /// exhausted (design §1.3: exhausted slots are retired, never wrapped).
  var freeList: [UInt32] = []
  /// Slots whose binding ended but whose payload has not been settled yet.
  ///
  /// Dequeued through `pendingHead` (head cursor) instead of
  /// `Array.removeFirst`: the pump drains under the metadata lock, and
  /// `removeFirst` shifts every remaining element, which the benchmark
  /// measured at 29.4–30.0 ms for a 32,768-deep drain (`docs/
  /// PERSISTENT_HANDLE_DESIGN.md` §11.3). The consumed prefix is compacted
  /// amortized-O(1) while the queue keeps churning, and dropped wholesale
  /// when it drains.
  var pending: [UInt32] = []
  var pendingHead = 0
  /// Next never-issued slab position. Fresh positions are handed out in
  /// ascending order, one chunk at a time.
  var nextFreshSlot: UInt32 = 0

  func locate(
    _ slot: UInt32
  ) -> (chunk: PersistentHandleSlotChunk<Owned>, index: Int)? {
    let chunkIndex = Int(slot) / persistentHandleSlotChunkCapacity
    guard chunkIndex < chunks.count else { return nil }
    return (chunks[chunkIndex], Int(slot) % persistentHandleSlotChunkCapacity)
  }
}

// MARK: - Registry

/// Non-generic cleanup target.
///
/// Capturing the generic registry directly in a `@Sendable` closure makes the
/// compiler capture `E.Type` (the generic metatype), which is not `Sendable`
/// under Swift 6.4's sendable-metatypes checking and produces a warning for
/// every release site. Scheduling through this existential erases the generic
/// argument; the closure still strongly holds the registry.
private protocol PersistentPumpTarget: AnyObject, Sendable {
  func pumpBindings()
}

/// Context-side binding registry (design §3).
///
/// Lifetime is owned by `JSContext`; the same object is also published into
/// the context data storage box so synchronous scope witnesses can reach it.
/// The registry holds the driver context handle as a **non-retaining value
/// copy** (`ScopeFrame.driverContextHandle` has the same discipline); every
/// engine call is guarded by `closed`, which `close()` sets before the
/// context's `releaseReference()`.
package final class JSPersistentHandleRegistry<E: JSEngineRuntimeDriver>: PersistentPumpTarget,
  @unchecked Sendable
{
  /// Process-wide, never-reused container identity (design §1.3).
  package let id: UInt64

  /// Non-retaining value copy; dereferenced by engine-touching paths only
  /// while the registry is not closed (design §3.1).
  let driverContextHandle: E.ContextHandle

  private let scheduler: any JSPersistentCleanupScheduler
  private let state = Mutex(PersistentHandleRegistryState<E.OwnedValueHandle>())

  package init(
    contextHandle: E.ContextHandle,
    scheduler: any JSPersistentCleanupScheduler
  ) {
    self.id = persistentHandleRegistryIDCounter.add(1, ordering: .relaxed).newValue
    self.driverContextHandle = contextHandle
    self.scheduler = scheduler
  }

  deinit {
    // Normal path is exactly one close (JSContext's isolated deinit). The
    // registry can outlive that body through a late pump closure; the flag
    // below is then already set and this assertion passes.
    assert(
      state.withLock { $0.closed },
      "JSPersistentHandleRegistry deallocated without close()"
    )
  }

  // MARK: Mint

  /// Mint a binding for a borrowed handle: claim an independent owned
  /// reference and root it (design §2.2), then store the payload in a slot.
  ///
  /// Copy semantics, unlike `persist`'s transfer: the source value stays
  /// usable, and one handle can be resolved any number of times.
  func makeHandle(_ handle: E.ValueHandle) -> JSPersistentHandle<E> {
    let identity = mint(handle)
    return JSPersistentHandle(identity: identity, registry: self)
  }

  private func mint(_ handle: E.ValueHandle) -> JSPersistentHandle<E>.Identity {
    // Every engine entry point checks `closed` under the lock first: after
    // `close()` the registry must never dereference the saved context handle
    // (design §3.1). Mint/close/pump all run on the VM thread, so this check
    // is not racing a settlement.
    guard state.withLock({ !$0.closed }) else {
      preconditionFailure(
        "JSPersistentHandleRegistry cannot mint: registry is closed")
    }

    // Called on the VM thread only (actor/scope witness), so the claim and
    // root below are serialized with every other payload operation.
    let owned = driverContextHandle.claimOwnedValueHandle(handle)
    driverContextHandle.rootOwnedValueHandle(owned)

    guard let slot = allocateSlot() else {
      // Slab exhausted (a concurrent close is impossible on this thread).
      // Settle the freshly claimed reference and fail like the existing
      // factory failure paths do.
      driverContextHandle.unrootOwnedValueHandle(owned)
      driverContextHandle.releaseCreatedHandle(owned)
      preconditionFailure(
        "JSPersistentHandleRegistry cannot mint: slot space exhausted"
      )
    }

    // Only mint/close/pump move payloads and all three run on the VM thread;
    // the slot is not observable by anyone else until the handle is returned.
    slot.chunk.payloads.advanced(by: slot.index).initialize(to: owned)
    return JSPersistentHandle<E>.Identity(
      registry: id,
      slot: slot.slot,
      generation: slot.generation
    )
  }

  private struct AllocatedSlot {
    let chunk: PersistentHandleSlotChunk<E.OwnedValueHandle>
    let index: Int
    let slot: UInt32
    let generation: UInt32
  }

  private func allocateSlot() -> AllocatedSlot? {
    state.withLock { state -> AllocatedSlot? in
      guard !state.closed else { return nil }

      if let slot = state.freeList.popLast() {
        guard let located = state.locate(slot) else { return nil }
        // Issue +1. A slot is never free-listed once its generation has
        // reached `UInt32.max` (see `release`), so wrapping cannot occur.
        let generation = located.chunk.generations[located.index]
        precondition(
          generation < UInt32.max,
          "retired persistent handle slot appeared on the free list"
        )
        located.chunk.generations[located.index] = generation + 1
        located.chunk.states[located.index] = PersistentSlotState.live.rawValue
        return AllocatedSlot(
          chunk: located.chunk,
          index: located.index,
          slot: slot,
          generation: generation + 1
        )
      }

      // `UInt32.max` fresh positions would overflow the slot index; treat it
      // as exhaustion (design §3.4/§3.6: 4G concurrent bindings is not a
      // realistic constraint for this layer).
      guard state.nextFreshSlot < UInt32.max else { return nil }
      let slot = state.nextFreshSlot
      state.nextFreshSlot += 1

      let chunkIndex = Int(slot) / persistentHandleSlotChunkCapacity
      if chunkIndex == state.chunks.count {
        state.chunks.append(
          PersistentHandleSlotChunk<E.OwnedValueHandle>(
            capacity: persistentHandleSlotChunkCapacity)
        )
      }
      let chunk = state.chunks[chunkIndex]
      let index = Int(slot) % persistentHandleSlotChunkCapacity
      // 0 means "never issued": a zero-initialized identity never matches.
      chunk.generations[index] = 1
      chunk.states[index] = PersistentSlotState.live.rawValue
      return AllocatedSlot(
        chunk: chunk,
        index: index,
        slot: slot,
        generation: 1
      )
    }
  }

  // MARK: Resolve

  /// Look up a live binding and return its copyable borrow token.
  ///
  /// The liveness check runs under the mutex; the payload is borrowed after
  /// the lock (design §3.5). Only mint/close/pump move payloads, and all of
  /// them share the VM thread with this call, so nothing can vacate the slot
  /// between the check and the borrow. `release` from another thread only
  /// changes metadata.
  func borrowLive(_ identity: JSPersistentHandle<E>.Identity) -> E.ValueHandle? {
    guard identity.registry == id else { return nil }

    let located: (chunk: PersistentHandleSlotChunk<E.OwnedValueHandle>, index: Int)? =
      state.withLock { state in
        guard !state.closed else { return nil }
        guard let located = state.locate(identity.slot) else { return nil }
        guard located.chunk.generations[located.index] == identity.generation,
          located.chunk.states[located.index] == PersistentSlotState.live.rawValue
        else { return nil }
        return located
      }
    guard let located else { return nil }
    return located.chunk.payloads.advanced(by: located.index).pointee.borrowed()
  }

  // MARK: Release

  /// Kill a binding's identity and schedule its engine settlement on the VM
  /// executor (design §2.3/§2.5).
  ///
  /// Any thread; metadata only. Returns `true` when this call ended a live
  /// binding. Idempotent: a second call, a call after `close()`, and a call
  /// for a mismatched generation all return `false`.
  @discardableResult
  func release(_ identity: JSPersistentHandle<E>.Identity) -> Bool {
    guard identity.registry == id else { return false }

    let (killed, needsPump) = state.withLock { state -> (Bool, Bool) in
      guard !state.closed else { return (false, false) }
      guard let located = state.locate(identity.slot) else { return (false, false) }
      guard located.chunk.generations[located.index] == identity.generation,
        located.chunk.states[located.index] == PersistentSlotState.live.rawValue
      else { return (false, false) }

      // Identity dies immediately: the generation is bumped so the handle can
      // never resolve again, even before the payload is reclaimed. When the
      // generation has reached `UInt32.max`, the slot is retired: it is
      // settled below but never re-enters the free list, so a future issue
      // can neither wrap nor collide (design §1.3).
      if located.chunk.generations[located.index] < UInt32.max {
        located.chunk.generations[located.index] += 1
      }
      located.chunk.states[located.index] = PersistentSlotState.pendingRelease.rawValue
      state.pending.append(identity.slot)

      if state.pumpScheduled { return (true, false) }
      state.pumpScheduled = true
      return (true, true)
    }

    if needsPump {
      // The closure strongly holds the registry until it runs; that may delay
      // the registry's own release but never extends the engine's lifetime
      // (`close()` already set `closed`, so a late pump is a no-op).
      let target: any PersistentPumpTarget = self
      scheduler.schedulePersistentCleanup { target.pumpBindings() }
    }
    return killed
  }

  func pumpBindings() {
    pump()
  }

  /// Fill the free list and settle pending bindings. VM thread only.
  private func pump() {
    while true {
      let work = state.withLock {
        state -> PersistentSettlement<E.OwnedValueHandle>? in
        if state.closed {
          state.pumpScheduled = false
          return nil
        }
        while state.pendingHead < state.pending.count {
          let slot = state.pending[state.pendingHead]
          state.pendingHead &+= 1
          // Compact the consumed prefix while entries keep arriving, so a
          // churning queue never retains more than ~2x its live depth
          // (trigger: the dead prefix is large and at least half the
          // array). Work per compaction is bounded by the dequeues since
          // the previous one — amortized O(1).
          if state.pendingHead >= 32 && state.pendingHead * 2 >= state.pending.count {
            state.pending.removeFirst(state.pendingHead)
            state.pendingHead = 0
          }
          guard let located = state.locate(slot),
            located.chunk.states[located.index]
              == PersistentSlotState.pendingRelease.rawValue
          else { continue }
          located.chunk.states[located.index] = PersistentSlotState.settling.rawValue
          return PersistentSettlement(
            chunk: located.chunk,
            index: located.index,
            slot: slot,
            payload: located.chunk.payloads.advanced(by: located.index).move()
          )
        }
        state.pending.removeAll()
        state.pendingHead = 0
        state.pumpScheduled = false
        return nil
      }
      guard let work = consume work else { return }

      let chunk = work.chunk
      let index = work.index
      let slot = work.slot
      settle(work.payload)

      state.withLock { state in
        chunk.states[index] = PersistentSlotState.free.rawValue
        // Retired slots (generation exhausted) never return to the free list.
        if chunk.generations[index] < UInt32.max {
          state.freeList.append(slot)
        }
      }
    }
  }

  /// Unroot and release one payload. Engine calls only — never inside the
  /// metadata lock (QuickJS `JS_FreeValue` can synchronously run a user
  /// finalizer that re-enters `release`, and `Mutex` is not recursive).
  private func settle(_ payload: consuming E.OwnedValueHandle) {
    driverContextHandle.unrootOwnedValueHandle(payload)
    driverContextHandle.releaseCreatedHandle(payload)
  }

  // MARK: Close

  /// Settle every live binding inline (design §3.5/§4.1). VM thread only;
  /// called from `JSContext.isolated deinit` before `releaseReference()`.
  ///
  /// Order is mandatory: set `closed` under the lock **first**, then scan.
  /// A `release` arriving after the flag flip is a no-op, so no
  /// `pendingRelease` can be stranded without a pump.
  package func close() {
    let slots: [UInt32] = state.withLock { state -> [UInt32] in
      guard !state.closed else { return [] }
      state.closed = true
      state.pumpScheduled = false
      state.pending.removeAll()
      state.pendingHead = 0

      var toSettle: [UInt32] = []
      for (chunkIndex, chunk) in state.chunks.enumerated() {
        for index in 0..<chunk.capacity {
          let slotState = chunk.states[index]
          if slotState == PersistentSlotState.live.rawValue
            || slotState == PersistentSlotState.pendingRelease.rawValue
          {
            // Death semantics also apply to container shutdown: bump the
            // generation (unless it is exhausted) so no surviving identity
            // can ever be mistaken for a future occupant, then move the
            // payload out of the slot.
            if chunk.generations[index] < UInt32.max {
              chunk.generations[index] += 1
            }
            chunk.states[index] = PersistentSlotState.settling.rawValue
            toSettle.append(
              UInt32(chunkIndex * persistentHandleSlotChunkCapacity + index))
          }
        }
      }
      state.freeList.removeAll()
      return toSettle
    }

    for slot in slots {
      let work = state.withLock {
        state -> PersistentSettlement<E.OwnedValueHandle>? in
        guard let located = state.locate(slot),
          located.chunk.states[located.index]
            == PersistentSlotState.settling.rawValue
        else { return nil }
        return PersistentSettlement(
          chunk: located.chunk,
          index: located.index,
          slot: slot,
          payload: located.chunk.payloads.advanced(by: located.index).move()
        )
      }
      guard let work = consume work else { continue }

      let chunk = work.chunk
      let index = work.index
      settle(work.payload)
      state.withLock { state in
        chunk.states[index] = PersistentSlotState.free.rawValue
      }
    }
  }
}

// MARK: - Context data key

/// Addresses a context's registry inside `JSContextDataStorageBox`.
///
/// The box is the synchronous access path for scope witnesses (callbacks
/// cannot touch the actor). The registry's lifetime is still owned by
/// `JSContext`, so an external box clear only removes this access path
/// (design §3.1).
package enum JSPersistentHandleRegistryKey<E: JSEngineRuntimeDriver>: JSContextDataKey {
  package typealias Value = JSPersistentHandleRegistry<E>
}

/// Registry lookup through the context data storage box.
extension JSPersistentHandleRegistry {
  package static func registry(
    for context: E.ContextHandle
  ) -> JSPersistentHandleRegistry<E>? {
    context.contextDataStorageBox()?.data(
      for: JSPersistentHandleRegistryKey<E>.self)
  }
}
