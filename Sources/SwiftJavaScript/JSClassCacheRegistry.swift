import Foundation

package final class JSClassCacheRegistry<Key: Hashable, Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [Key: Value] = [:]

  package init() {}

  package func value(for key: Key, build makeValue: () -> Value) -> Value {
    lock.lock()
    if let existing = map[key] {
      lock.unlock()
      return existing
    }
    lock.unlock()

    let created = makeValue()

    lock.lock()
    if let existing = map[key] {
      lock.unlock()
      return existing
    }
    map[key] = created
    lock.unlock()
    return created
  }
}
