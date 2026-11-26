import JavaScriptCore
import SwiftJavaScript
import Synchronization

private let jscPersistentBindingsCounter = Atomic<UInt64>(0)

/// JavaScriptCore's concrete persistent-binding table.
///
/// JSC is GC-managed, so a live binding is a protected `JSValueRef`; release
/// removes the slot metadata immediately and unprotects the reference on the
/// VM thread. The table never outlives the context actor: `close()` runs in
/// the actor's isolated deinit before the context itself is released.
final class JSCPersistentBindings: @unchecked Sendable {
  private struct Slot: @unchecked Sendable {
    var ref: JSValueRef?
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
  private let contextRef: JSGlobalContextRef
  private let vmThread: VMThread
  private let state = Mutex(State())

  init(contextRef: JSGlobalContextRef, vmThread: VMThread) {
    self.id =
      0x4A53_4300_0000_0000
      | jscPersistentBindingsCounter.add(1, ordering: .relaxed).newValue
    self.contextRef = contextRef
    self.vmThread = vmThread
  }

  func mint(_ ref: JSValueRef) -> JSPersistentHandleIdentity {
    let identity = state.withLock { state -> JSPersistentHandleIdentity in
      precondition(!state.closed, "JSCPersistentBindings cannot mint after close")
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
      entry.ref = ref
      entry.live = true
      state.slots[slot] = entry
      return JSPersistentHandleIdentity(
        registry: id,
        slot: slot,
        generation: entry.generation
      )
    }
    JSValueProtect(contextRef, ref)
    return identity
  }

  func borrowLive(_ identity: JSPersistentHandleIdentity) -> JSValueRef? {
    guard identity.registry == id else { return nil }
    return state.withLock { state in
      guard !state.closed,
        let entry = state.slots[identity.slot],
        entry.live,
        entry.generation == identity.generation
      else {
        return nil
      }
      return entry.ref
    }
  }

  @discardableResult
  func release(_ identity: JSPersistentHandleIdentity) -> Bool {
    guard identity.registry == id else { return false }
    let released: JSValueRef? = state.withLock { state in
      guard !state.closed,
        var entry = state.slots[identity.slot],
        entry.live,
        entry.generation == identity.generation
      else {
        return nil
      }
      let ref = entry.ref
      entry.live = false
      entry.ref = nil
      if entry.generation < UInt32.max {
        entry.generation += 1
      }
      state.slots[identity.slot] = entry
      state.free.append(identity.slot)
      return ref
    }
    guard let released else { return false }
    let contextBits = UInt(bitPattern: contextRef)
    let refBits = UInt(bitPattern: released)
    vmThread.perform {
      guard let contextRef = JSGlobalContextRef(bitPattern: contextBits),
        let ref = JSValueRef(bitPattern: refBits)
      else {
        return
      }
      JSValueUnprotect(contextRef, ref)
    }
    return true
  }

  func close() {
    let refs: [JSValueRef] = state.withLock { state in
      guard !state.closed else { return [] }
      state.closed = true
      var collected: [JSValueRef] = []
      for (slot, var entry) in state.slots where entry.live {
        if let ref = entry.ref {
          collected.append(ref)
        }
        entry.live = false
        entry.ref = nil
        state.slots[slot] = entry
      }
      return collected
    }
    guard !refs.isEmpty else { return }
    let contextBits = UInt(bitPattern: contextRef)
    let refBits = refs.map(UInt.init(bitPattern:))
    vmThread.perform {
      guard let contextRef = JSGlobalContextRef(bitPattern: contextBits) else {
        return
      }
      for bits in refBits {
        if let ref = JSValueRef(bitPattern: bits) {
          JSValueUnprotect(contextRef, ref)
        }
      }
    }
  }
}

/// Non-generic weak box used by `JSCPersistentHandle`: the handle must not
/// keep the context's binding table alive, and a `Sendable` class cannot hold
/// a mutable `weak` storage property directly.
final class JSCPersistentBindingsReference: @unchecked Sendable {
  private weak var value: JSCPersistentBindings?

  init(_ value: JSCPersistentBindings) {
    self.value = value
  }

  var bindings: JSCPersistentBindings? {
    value
  }
}

enum JSCPersistentBindingsKey: JSContextDataKey {
  typealias Value = JSCPersistentBindings
}

func javaScriptCorePersistentBindings(
  for contextRef: JSGlobalContextRef
) -> JSCPersistentBindings? {
  JSCEngine.contextDataStorageBox(in: contextRef)?.data(for: JSCPersistentBindingsKey.self)
}
