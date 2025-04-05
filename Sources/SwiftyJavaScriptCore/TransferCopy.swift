protocol TransferableCopy where Self: ~Copyable & Sendable {
  init(copying other: borrowing Self)
}

extension TransferableCopy {
  public func copy() -> Self {
    Self.init(copying: self)
  }
}
