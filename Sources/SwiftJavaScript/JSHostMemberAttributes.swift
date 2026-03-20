public struct JSHostMemberAttributes: Sendable, Hashable, OptionSet {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let none: JSHostMemberAttributes = []
  public static let readOnly = JSHostMemberAttributes(rawValue: 1 << 0)
  public static let dontEnum = JSHostMemberAttributes(rawValue: 1 << 1)
  public static let dontDelete = JSHostMemberAttributes(rawValue: 1 << 2)
}
