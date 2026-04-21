import Synchronization

package struct JSClassMapRegistry<Key: Hashable & Sendable, Value: Sendable>:
  Sendable, ~Copyable
{
  private let map = Mutex<[Key: Value]>([:])

  package init() {}

  package subscript(_ key: Key) -> Value? {
    get {
      map.withLock {
        $0[key]
      }
    }
    nonmutating set {
      map.withLock {
        $0[key] = newValue
      }
    }
  }

  package func value(forKey key: Key, orInsert makeValue: () -> Value) -> Value {
    if let existing = self[key] {
      return existing
    }

    let created = makeValue()

    return map.withLock {
      if let existing = $0[key] {
        return existing
      }
      $0[key] = created
      return created
    }
  }

  @discardableResult
  package func removeValue(forKey key: Key) -> Value? {
    map.withLock {
      $0.removeValue(forKey: key)
    }
  }
}

package struct JSClassDefinitionDepthRegistry<Key: Hashable & Sendable, Definition: Sendable>:
  Sendable, ~Copyable
{
  private let map = Mutex<[Key: (definition: Definition, depth: Int)]>([:])

  package init() {}

  package func set(_ key: Key, definition: Definition, depth: Int) {
    map.withLock {
      if let current = $0[key], current.depth > depth {
        return
      }
      $0[key] = (definition, depth)
    }
  }

  package func get(_ key: Key) -> Definition? {
    map.withLock {
      $0[key]?.definition
    }
  }

  package func remove(_ key: Key) {
    _ = map.withLock {
      $0.removeValue(forKey: key)
    }
  }
}

package struct JSClassFinalizeCounterRegistry<Key: Hashable & Sendable>: Sendable, ~Copyable {
  private let map = Mutex<[Key: Int]>([:])

  package init() {}

  package func setMax(_ key: Key, count: Int) {
    map.withLock {
      $0[key] = max(count, $0[key] ?? 0)
    }
  }

  package func decrement(_ key: Key) -> Int {
    map.withLock {
      let current = $0[key] ?? 1
      let next = current - 1
      if next <= 0 {
        $0.removeValue(forKey: key)
      } else {
        $0[key] = next
      }
      return next
    }
  }
}
