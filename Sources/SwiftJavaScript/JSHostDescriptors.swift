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

public enum JSHostObjectStoragePolicy: Sendable, Hashable {
  case unmanagedOpaquePointer
  case swiftRetainedObject
  case valueSemanticCopy
}

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

public struct JSHostConstructorDescriptor: Sendable, Hashable {
  public var binding: String?

  public init(binding: String? = nil) {
    self.binding = binding
  }
}

public struct JSHostTypeDescriptor: Sendable {
  public var name: String
  public var constructor: JSHostConstructorDescriptor?
  public var methods: [JSHostFunctionDescriptor]
  public var staticMethods: [JSHostFunctionDescriptor]
  public var properties: [JSHostPropertyDescriptor]
  public var parent: String?
  public var storagePolicy: JSHostObjectStoragePolicy
  public var initializerBinding: String?
  public var finalizerBinding: String?
  public var dynamicPropertyGetterBinding: String?
  public var dynamicPropertySetterBinding: String?
  public var dynamicPropertyHasBinding: String?
  public var dynamicPropertyDeleteBinding: String?
  public var propertyEnumeratorBinding: String?
  public var callAsFunctionBinding: String?
  public var hasInstanceBinding: String?
  public var convertToTypeBinding: String?

  public init(
    name: String,
    constructor: JSHostConstructorDescriptor? = nil,
    methods: [JSHostFunctionDescriptor] = [],
    staticMethods: [JSHostFunctionDescriptor] = [],
    properties: [JSHostPropertyDescriptor] = [],
    parent: String? = nil,
    storagePolicy: JSHostObjectStoragePolicy = .swiftRetainedObject,
    initializerBinding: String? = nil,
    finalizerBinding: String? = nil,
    dynamicPropertyGetterBinding: String? = nil,
    dynamicPropertySetterBinding: String? = nil,
    dynamicPropertyHasBinding: String? = nil,
    dynamicPropertyDeleteBinding: String? = nil,
    propertyEnumeratorBinding: String? = nil,
    callAsFunctionBinding: String? = nil,
    hasInstanceBinding: String? = nil,
    convertToTypeBinding: String? = nil
  ) {
    self.name = name
    self.constructor = constructor
    self.methods = methods
    self.staticMethods = staticMethods
    self.properties = properties
    self.parent = parent
    self.storagePolicy = storagePolicy
    self.initializerBinding = initializerBinding
    self.finalizerBinding = finalizerBinding
    self.dynamicPropertyGetterBinding = dynamicPropertyGetterBinding
    self.dynamicPropertySetterBinding = dynamicPropertySetterBinding
    self.dynamicPropertyHasBinding = dynamicPropertyHasBinding
    self.dynamicPropertyDeleteBinding = dynamicPropertyDeleteBinding
    self.propertyEnumeratorBinding = propertyEnumeratorBinding
    self.callAsFunctionBinding = callAsFunctionBinding
    self.hasInstanceBinding = hasInstanceBinding
    self.convertToTypeBinding = convertToTypeBinding
  }
}
