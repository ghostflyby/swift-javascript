public struct JSEngineCapabilities: Sendable, Hashable {
  public var supportsBigInt: Bool
  public var supportsSymbol: Bool
  public var supportsExternalArrayBuffer: Bool
  public var supportsHostObjects: Bool
  public var supportsESModules: Bool
  public var supportsPromiseJobQueueControl: Bool

  public init(
    supportsBigInt: Bool = false,
    supportsSymbol: Bool = false,
    supportsExternalArrayBuffer: Bool = false,
    supportsHostObjects: Bool = false,
    supportsESModules: Bool = false,
    supportsPromiseJobQueueControl: Bool = false
  ) {
    self.supportsBigInt = supportsBigInt
    self.supportsSymbol = supportsSymbol
    self.supportsExternalArrayBuffer = supportsExternalArrayBuffer
    self.supportsHostObjects = supportsHostObjects
    self.supportsESModules = supportsESModules
    self.supportsPromiseJobQueueControl = supportsPromiseJobQueueControl
  }
}
