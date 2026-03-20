public struct JSHostConstantDescriptor: Sendable {
  public var name: String
  public var value: any Sendable
  public var attributes: JSHostMemberAttributes

  public init(
    name: String,
    value: any Sendable,
    attributes: JSHostMemberAttributes = .none
  ) {
    self.name = name
    self.value = value
    self.attributes = attributes
  }
}
