package final class Box<T: ~Copyable> {
  package let value: T

  package init(_ value: consuming T) {
    self.value = value
  }
}
