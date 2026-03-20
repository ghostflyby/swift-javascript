import Testing

@testable import SwiftJavaScript

struct CopyableValue: Sendable, TransferableCopy {
  let value: Int

  init(_ value: Int) {
    self.value = value
  }

  init(copying other: borrowing CopyableValue) {
    self.value = other.value + 1
  }
}

@Test func copyUsesInitCopying() {
  let original = CopyableValue(10)
  let copied = original.copy()

  #expect(copied.value == 11)
}

@Test func copyCanBeChained() {
  let original = CopyableValue(0)
  let copied1 = original.copy()
  let copied2 = copied1.copy()

  #expect(copied1.value == 1)
  #expect(copied2.value == 2)
}
