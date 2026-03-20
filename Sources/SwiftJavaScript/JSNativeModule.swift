public struct JSHostModuleDescriptor: Sendable {
  public var name: String
  public var functions: [JSHostFunctionDescriptor]
  public var constants: [JSHostConstantDescriptor]
  public var types: [JSHostTypeDescriptor]

  public init(
    name: String,
    functions: [JSHostFunctionDescriptor] = [],
    constants: [JSHostConstantDescriptor] = [],
    types: [JSHostTypeDescriptor] = []
  ) {
    self.name = name
    self.functions = functions
    self.constants = constants
    self.types = types
  }
}

public protocol JSNativeModule: Sendable {
  static var moduleName: String { get }
  static var descriptor: JSHostModuleDescriptor { get }
}
