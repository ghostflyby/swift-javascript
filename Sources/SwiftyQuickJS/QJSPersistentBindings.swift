import SwiftJavaScript
import Synchronization

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

private let qjsPersistentBindingsCounter = Atomic<UInt64>(0)

/// QuickJS's concrete persistent-binding table.
///
/// QuickJS is reference-counted, so a live binding owns one duplicated
/// reference (`JS_DupValue`) and settlement is `JS_FreeValue` exactly once per
/// slot: `take` clears the slot metadata under the lock and hands the captured
/// reference to the context actor, which frees it on the VM executor; `close`
/// settles every still-live slot inline, so a released slot can never be
/// settled twice. The table never outlives the context actor: `close()` runs in
/// the actor's isolated deinit before `JS_FreeContext`.
final class QJSPersistentBindings: @unchecked Sendable {
  private struct Slot: @unchecked Sendable {
    var value: CQuickJSValue?
    var generation: UInt32 = 0
    var live = false
  }

  private struct State: @unchecked Sendable {
    var slots: [UInt32: Slot] = [:]
    var free: [UInt32] = []
    var next: UInt32 = 0
    var closed = false
  }

  let id: UInt64
  private let contextRef: OpaquePointer
  private let state = Mutex(State())

  init(contextRef: OpaquePointer) {
    self.id =
      0x514A_5300_0000_0000
      | qjsPersistentBindingsCounter.add(1, ordering: .relaxed).newValue
    self.contextRef = contextRef
  }

  /// Copy semantics: minting duplicates the borrowed value, so the source
  /// value stays valid for the rest of its window and the binding can be
  /// resolved any number of times.
  func mint(_ value: CQuickJSValue) -> JSPersistentHandleIdentity {
    let identity = state.withLock { state -> JSPersistentHandleIdentity in
      precondition(!state.closed, "QJSPersistentBindings cannot mint after close")
      let slot: UInt32
      if let reused = state.free.popLast() {
        slot = reused
      } else {
        precondition(state.next < UInt32.max, "persistent binding slots exhausted")
        slot = state.next
        state.next += 1
      }
      var entry = state.slots[slot] ?? Slot()
      precondition(entry.generation < UInt32.max, "persistent binding generation overflow")
      entry.generation += 1
      entry.value = value
      entry.live = true
      state.slots[slot] = entry
      return JSPersistentHandleIdentity(
        registry: id,
        slot: slot,
        generation: entry.generation
      )
    }
    quickJSUpdateStackTop(contextRef)
    _ = JS_DupValue(contextRef, value)
    return identity
  }

  /// The live binding's borrowed identity, or `nil` for a dead, foreign, or
  /// already-closed binding.
  func borrowLive(_ identity: JSPersistentHandleIdentity) -> CQuickJSValue? {
    guard identity.registry == id else { return nil }
    return state.withLock { state in
      guard !state.closed,
        let entry = state.slots[identity.slot],
        entry.live,
        entry.generation == identity.generation
      else {
        return nil
      }
      return entry.value
    }
  }

  /// Kill a binding synchronously and hand its owned reference to the caller,
  /// who frees it on the VM executor. Any thread; metadata only under the
  /// lock. Idempotent: a second call, a call after `close()`, and a call for a
  /// mismatched generation all return `nil` and free nothing.
  func take(_ identity: JSPersistentHandleIdentity) -> CQuickJSValue? {
    guard identity.registry == id else { return nil }
    return state.withLock { state in
      guard !state.closed,
        var entry = state.slots[identity.slot],
        entry.live,
        entry.generation == identity.generation
      else {
        return nil
      }
      let value = entry.value
      entry.live = false
      entry.value = nil
      if entry.generation < UInt32.max {
        entry.generation += 1
      }
      state.slots[identity.slot] = entry
      state.free.append(identity.slot)
      return value
    }
  }

  /// Settle every live binding inline. VM executor only; called from the host
  /// context actor's isolated deinit before `JS_FreeContext`.
  func close() {
    let values: [CQuickJSValue] = state.withLock { state in
      guard !state.closed else { return [] }
      state.closed = true
      var collected: [CQuickJSValue] = []
      for (slot, var entry) in state.slots where entry.live {
        if let value = entry.value {
          collected.append(value)
        }
        entry.live = false
        entry.value = nil
        state.slots[slot] = entry
      }
      state.free.removeAll()
      return collected
    }
    guard !values.isEmpty else { return }
    quickJSUpdateStackTop(contextRef)
    for value in values {
      JS_FreeValue(contextRef, value)
    }
  }
}

/// Non-generic weak box used by `QJSPersistentHandle`: the handle must not
/// keep the context's binding table alive, and a `Sendable` class cannot hold
/// a mutable `weak` storage property directly.
final class QJSPersistentBindingsReference: @unchecked Sendable {
  private weak var value: QJSPersistentBindings?

  init(_ value: QJSPersistentBindings) {
    self.value = value
  }

  var bindings: QJSPersistentBindings? {
    value
  }
}

enum QJSPersistentBindingsKey: JSContextDataKey {
  typealias Value = QJSPersistentBindings
}

func quickJSPersistentBindings(for contextRef: OpaquePointer) -> QJSPersistentBindings? {
  QJSEngine.contextDataStorageBox(in: contextRef)?.data(for: QJSPersistentBindingsKey.self)
}
