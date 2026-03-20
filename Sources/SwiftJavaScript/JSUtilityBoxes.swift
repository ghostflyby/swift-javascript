package final class Box<T: ~Copyable> {
  package let value: T

  package init(_ value: consuming T) {
    self.value = value
  }
}

package struct SendableBoxUnsafe<T: ~Copyable>: @unchecked Sendable, ~Copyable {
  package let value: T

  package init(_ value: consuming T) {
    self.value = value
  }
}

extension SendableBoxUnsafe: Copyable where T: Copyable {}
