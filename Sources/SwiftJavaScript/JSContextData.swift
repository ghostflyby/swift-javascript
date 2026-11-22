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

  package func bindContextOwner<E: JSContextEngine>(_ owner: JSContext<E>) {
    state.withLock {
      $0.ownerAddress = UInt(bitPattern: Unmanaged.passUnretained(owner).toOpaque())
    }
  }

  package func borrowContextOwner<E: JSContextEngine>(
    as engine: E.Type = E.self
  ) -> JSContext<E>? {
    _ = engine
    guard
      let ownerAddress = state.withLock({ $0.ownerAddress }),
      let owner = UnsafeMutableRawPointer(bitPattern: ownerAddress)
    else {
      return nil
    }
    return Unmanaged<JSContext<E>>.fromOpaque(owner).takeUnretainedValue()
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
