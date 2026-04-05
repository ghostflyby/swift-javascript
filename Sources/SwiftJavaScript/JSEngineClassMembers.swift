public struct JSEngineStaticValue<E: JSEngine>: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let getProperty:
    @Sendable (borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>)
      -> JSResult<JSEngineValue<E>>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    getProperty:
      @escaping @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>
      ) -> JSResult<JSEngineValue<E>>,
    setProperty:
      @escaping @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSEngineValue<E>
      ) -> JSResult<JSEngineValue<E>>
  ) {
    self.name = name
    self.attributes = attributes
    self.getProperty = getProperty
    self.setProperty = setProperty
  }
  public let setProperty:
    @Sendable (
      borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSEngineValue<E>
    )
      -> JSResult<JSEngineValue<E>>
}

public struct JSEngineStaticFunction<E: JSEngine>: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let callAsFunction:
    @Sendable (
      borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSArguments<E>
    ) -> JSResult<JSEngineValue<E>>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    callAsFunction:
      @escaping @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSArguments<E>
      ) -> JSResult<JSEngineValue<E>>
  ) {
    self.name = name
    self.attributes = attributes
    self.callAsFunction = callAsFunction
  }
}

extension JSEngineStaticValue {
  public func hostPropertyDescriptor(
    getterBinding: String? = nil,
    setterBinding: String? = nil
  ) -> JSHostPropertyDescriptor {
    JSHostPropertyDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      getterBinding: getterBinding,
      setterBinding: setterBinding
    )
  }
}

extension JSEngineStaticFunction {
  public func hostFunctionDescriptor(binding: String? = nil) -> JSHostFunctionDescriptor {
    JSHostFunctionDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      binding: binding
    )
  }
}

package struct JSClassHostDescriptorProjectionFlags: Sendable {
  package let hasInitializer: Bool
  package let hasFinalizer: Bool
  package let hasDynamicPropertyGetter: Bool
  package let hasDynamicPropertySetter: Bool
  package let hasDynamicPropertyHas: Bool
  package let hasDynamicPropertyDelete: Bool
  package let hasPropertyEnumerator: Bool
  package let hasCallAsFunction: Bool
  package let hasConstructor: Bool
  package let hasHasInstance: Bool
  package let hasConvertToType: Bool

  package init(
    hasInitializer: Bool,
    hasFinalizer: Bool,
    hasDynamicPropertyGetter: Bool,
    hasDynamicPropertySetter: Bool,
    hasDynamicPropertyHas: Bool,
    hasDynamicPropertyDelete: Bool,
    hasPropertyEnumerator: Bool,
    hasCallAsFunction: Bool,
    hasConstructor: Bool,
    hasHasInstance: Bool,
    hasConvertToType: Bool
  ) {
    self.hasInitializer = hasInitializer
    self.hasFinalizer = hasFinalizer
    self.hasDynamicPropertyGetter = hasDynamicPropertyGetter
    self.hasDynamicPropertySetter = hasDynamicPropertySetter
    self.hasDynamicPropertyHas = hasDynamicPropertyHas
    self.hasDynamicPropertyDelete = hasDynamicPropertyDelete
    self.hasPropertyEnumerator = hasPropertyEnumerator
    self.hasCallAsFunction = hasCallAsFunction
    self.hasConstructor = hasConstructor
    self.hasHasInstance = hasHasInstance
    self.hasConvertToType = hasConvertToType
  }
}

package func projectClassHostTypeDescriptor<E: JSEngine>(
  className: String?,
  parentName: String?,
  staticValues: [JSEngineStaticValue<E>],
  staticFunctions: [JSEngineStaticFunction<E>],
  storagePolicy: JSHostObjectStoragePolicy,
  flags: JSClassHostDescriptorProjectionFlags
) -> JSHostTypeDescriptor {
  let typeName = className ?? "AnonymousHostType"

  return JSHostTypeDescriptor(
    name: typeName,
    constructor: flags.hasConstructor
      ? JSHostConstructorDescriptor(binding: classHostBindingName(className, suffix: "constructor"))
      : nil,
    methods: staticFunctions.map {
      $0.hostFunctionDescriptor(
        binding: classHostBindingName(className, suffix: "method.\($0.name)"))
    },
    staticMethods: [],
    properties: staticValues.map {
      $0.hostPropertyDescriptor(
        getterBinding: classHostBindingName(className, suffix: "property.get.\($0.name)"),
        setterBinding: classHostBindingName(className, suffix: "property.set.\($0.name)")
      )
    },
    parent: parentName,
    storagePolicy: storagePolicy,
    initializerBinding: flags.hasInitializer
      ? classHostBindingName(className, suffix: "initialize")
      : nil,
    finalizerBinding: flags.hasFinalizer
      ? classHostBindingName(className, suffix: "finalize")
      : nil,
    dynamicPropertyGetterBinding: flags.hasDynamicPropertyGetter
      ? classHostBindingName(className, suffix: "dynamicProperty.get")
      : nil,
    dynamicPropertySetterBinding: flags.hasDynamicPropertySetter
      ? classHostBindingName(className, suffix: "dynamicProperty.set")
      : nil,
    dynamicPropertyHasBinding: flags.hasDynamicPropertyHas
      ? classHostBindingName(className, suffix: "dynamicProperty.has")
      : nil,
    dynamicPropertyDeleteBinding: flags.hasDynamicPropertyDelete
      ? classHostBindingName(className, suffix: "dynamicProperty.delete")
      : nil,
    propertyEnumeratorBinding: flags.hasPropertyEnumerator
      ? classHostBindingName(className, suffix: "dynamicProperty.enumerate")
      : nil,
    callAsFunctionBinding: flags.hasCallAsFunction
      ? classHostBindingName(className, suffix: "call")
      : nil,
    hasInstanceBinding: flags.hasHasInstance
      ? classHostBindingName(className, suffix: "hasInstance")
      : nil,
    convertToTypeBinding: flags.hasConvertToType
      ? classHostBindingName(className, suffix: "convertToType")
      : nil
  )
}

private func classHostBindingName(_ className: String?, suffix: String) -> String {
  guard let className, !className.isEmpty else {
    return suffix
  }
  return "\(className).\(suffix)"
}
