import Foundation

package final class JSClassMapRegistry<Key: Hashable, Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: Value] = [:]

  package init() {}

  package func set(_ key: Key, value: Value) {
    lock.lock()
    map[key] = value
    lock.unlock()
  }

  package func get(_ key: Key) -> Value? {
    lock.lock()
    let value = map[key]
    lock.unlock()
    return value
  }

  package func remove(_ key: Key) {
    lock.lock()
    map.removeValue(forKey: key)
    lock.unlock()
  }
}

package final class JSClassDefinitionDepthRegistry<Key: Hashable, Definition>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: (definition: Definition, depth: Int)] = [:]

  package init() {}

  package func set(_ key: Key, definition: Definition, depth: Int) {
    lock.lock()
    if let current = map[key], current.depth > depth {
      lock.unlock()
      return
    }
    map[key] = (definition, depth)
    lock.unlock()
  }

  package func get(_ key: Key) -> Definition? {
    lock.lock()
    let value = map[key]?.definition
    lock.unlock()
    return value
  }

  package func remove(_ key: Key) {
    lock.lock()
    map.removeValue(forKey: key)
    lock.unlock()
  }
}

package final class JSClassFinalizeCounterRegistry<Key: Hashable>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: Int] = [:]

  package init() {}

  package func setMax(_ key: Key, count: Int) {
    lock.lock()
    map[key] = max(count, map[key] ?? 0)
    lock.unlock()
  }

  package func decrement(_ key: Key) -> Int {
    lock.lock()
    let current = map[key] ?? 1
    let next = current - 1
    if next <= 0 {
      map.removeValue(forKey: key)
    } else {
      map[key] = next
    }
    lock.unlock()
    return next
  }
}
