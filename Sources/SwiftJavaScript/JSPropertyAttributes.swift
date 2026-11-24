public struct JSPropertyAttributes: Sendable, Hashable, OptionSet {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

/// Projection onto the shared host member attributes used by the surface
/// scopes and global-object writers.
extension JSPropertyAttributes {
  public var hostMemberAttributes: JSHostMemberAttributes {
    var attributes: JSHostMemberAttributes = .none
    if contains(.readOnly) {
      attributes.insert(.readOnly)
    }
    if contains(.dontEnum) {
      attributes.insert(.dontEnum)
    }
    if contains(.dontDelete) {
      attributes.insert(.dontDelete)
    }
    return attributes
  }
}

extension JSPropertyAttributes {
  public static let none: JSPropertyAttributes = []
  public static let readOnly = JSPropertyAttributes(rawValue: 1 << 0)
  public static let dontEnum = JSPropertyAttributes(rawValue: 1 << 1)
  public static let dontDelete = JSPropertyAttributes(rawValue: 1 << 2)
}
