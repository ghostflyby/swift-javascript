public struct JSHostConstructorDescriptor: Sendable, Hashable {
  public var binding: String?

  public init(binding: String? = nil) {
    self.binding = binding
  }
}
