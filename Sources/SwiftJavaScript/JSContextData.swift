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
