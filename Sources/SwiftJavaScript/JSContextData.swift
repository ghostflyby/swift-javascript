import Synchronization

public protocol JSContextDataKey: Sendable {
  associatedtype Value: Sendable

  static var defaultValue: Value? { get }
}

extension JSContextDataKey {
  public static var defaultValue: Value? {
    nil
  }
}

public final class JSContextDataStorageBox: @unchecked Sendable {
  private struct State: Sendable {
    var ownerAddress: UInt?
    var data: [ObjectIdentifier: any Sendable] = [:]
  }

  private let state = Mutex(State())

  package init() {}

  /// Bind the context that installs this box as its unretained owner.
  ///
  /// The owner is erased to `AnyObject` because the installing context is an
  /// engine's concrete context actor (`JSCContext`, `QJSContext`); the engine
  /// that reads it back casts to the type it expects.
  package func bindContextOwner(_ owner: AnyObject) {
    state.withLock {
      $0.ownerAddress = UInt(bitPattern: Unmanaged.passUnretained(owner).toOpaque())
    }
  }

  /// The unretained owner bound by `bindContextOwner`, or `nil` when the box
  /// has no owner (a bare engine context or an already-cleared box).
  package func borrowContextOwner() -> AnyObject? {
    guard
      let ownerAddress = state.withLock({ $0.ownerAddress }),
      let owner = UnsafeMutableRawPointer(bitPattern: ownerAddress)
    else {
      return nil
    }
    return Unmanaged<AnyObject>.fromOpaque(owner).takeUnretainedValue()
  }

  package func setData<K: JSContextDataKey>(_ value: K.Value?, for key: K.Type) {
    _ = state.withLock {
      if let value {
        $0.data[ObjectIdentifier(key)] = value
      } else {
        $0.data.removeValue(forKey: ObjectIdentifier(key))
      }
    }
  }

  package func data<K: JSContextDataKey>(for key: K.Type) -> K.Value? {
    state.withLock {
      ($0.data[ObjectIdentifier(key)] as? K.Value) ?? K.defaultValue
    }
  }
}

// MARK: - VM-thread routing

extension JSEngineRuntimeDriver {
  /// Install, replace, or clear a context's data storage box without ever
  /// touching the engine off the context's VM thread.
  ///
  /// `raw` mutates engine state (JSC `JSObjectSetPrivate` on the global
  /// object, QuickJS `JS_SetContextOpaque`) and releases the displaced box, so
  /// it belongs on the VM thread (design §0.2.3). A context bound to a VM
  /// thread — every host `JSContext` actor, from the end of its `init` to its
  /// isolated deinit — swaps inline when the caller already is that thread and
  /// otherwise posts the swap to the VM thread's queue: the calling thread
  /// makes no engine call, and the swap lands ahead of anything enqueued
  /// after it, which also means the call returns before it takes effect. A
  /// context with no host actor has no VM thread to protect and swaps
  /// inline.
  package static func swapContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    on context: ContextHandle,
    raw: @escaping @Sendable (ContextHandle, JSContextDataStorageBox?) -> Void
  ) {
    guard let vmThread = ScopeStackRegistry<ContextHandle>.vmThread(for: context) else {
      raw(context, storage)
      return
    }
    vmThread.perform {
      raw(context, storage)
    }
  }
}
