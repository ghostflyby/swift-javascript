public struct JSHostFunctionDescriptor: Sendable, Hashable {
  public var name: String
  public var attributes: JSHostMemberAttributes
  public var binding: String?

  public init(
    name: String,
    attributes: JSHostMemberAttributes = .none,
    binding: String? = nil
  ) {
    self.name = name
    self.attributes = attributes
    self.binding = binding
  }
}
