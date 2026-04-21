public struct JSHostPropertyDescriptor: Sendable, Hashable {
  public var name: String
  public var attributes: JSHostMemberAttributes
  public var getterBinding: String?
  public var setterBinding: String?

  public init(
    name: String,
    attributes: JSHostMemberAttributes = .none,
    getterBinding: String? = nil,
    setterBinding: String? = nil
  ) {
    self.name = name
    self.attributes = attributes
    self.getterBinding = getterBinding
    self.setterBinding = setterBinding
  }
}
