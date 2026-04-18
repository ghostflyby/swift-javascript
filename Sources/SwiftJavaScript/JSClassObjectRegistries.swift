import Foundation

package final class JSClassMapRegistry<Key: Hashable, Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: Value] = [:]

  package init() {}

  package func set(_ key: Key, value: Value) {
    lock.withLock {
      map[key] = value
    }
  }

  package func get(_ key: Key) -> Value? {
    lock.withLock {
      map[key]
    }
  }

  package func remove(_ key: Key) {
    _ = lock.withLock {
      map.removeValue(forKey: key)
    }
  }
}

package final class JSClassDefinitionDepthRegistry<Key: Hashable, Definition>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: (definition: Definition, depth: Int)] = [:]

  package init() {}

  package func set(_ key: Key, definition: Definition, depth: Int) {
    lock.withLock {
      if let current = map[key], current.depth > depth {
        return
      }
      map[key] = (definition, depth)
    }
  }

  package func get(_ key: Key) -> Definition? {
    lock.withLock {
      map[key]?.definition
    }
  }

  package func remove(_ key: Key) {
    _ = lock.withLock {
      map.removeValue(forKey: key)
    }
  }
}

package final class JSClassFinalizeCounterRegistry<Key: Hashable>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: Int] = [:]

  package init() {}

  package func setMax(_ key: Key, count: Int) {
    lock.withLock {
      map[key] = max(count, map[key] ?? 0)
    }
  }

  package func decrement(_ key: Key) -> Int {
    lock.withLock {
      let current = map[key] ?? 1
      let next = current - 1
      if next <= 0 {
        map.removeValue(forKey: key)
      } else {
        map[key] = next
      }
      return next
    }
  }
}
