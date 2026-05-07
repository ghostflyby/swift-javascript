public struct JSClassAttributes: OptionSet, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let none: JSClassAttributes = []
  public static let noAutomaticPrototype = JSClassAttributes(rawValue: 1 << 0)
}
