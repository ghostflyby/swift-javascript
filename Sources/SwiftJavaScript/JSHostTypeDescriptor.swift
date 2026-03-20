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
