public struct JSClassStaticValueDefinition: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes

  public init(name: String, attributes: JSPropertyAttributes) {
    self.name = name
    self.attributes = attributes
  }
}

public struct JSClassStaticFunctionDefinition: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes

  public init(name: String, attributes: JSPropertyAttributes) {
    self.name = name
    self.attributes = attributes
  }
}

public struct JSStaticValue<E: JSEngine>: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let getProperty:
    @Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>)
      -> JSResult<JSValue<E>>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    getProperty:
      @escaping @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>
      ) -> JSResult<JSValue<E>>,
    setProperty:
      @escaping @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, borrowing JSValue<E>
      ) -> JSResult<JSValue<E>>
  ) {
    self.name = name
    self.attributes = attributes
    self.getProperty = getProperty
    self.setProperty = setProperty
  }
  public let setProperty:
    @Sendable (
      borrowing JSInstantContext<E>, borrowing JSValue<E>, borrowing JSValue<E>
    )
      -> JSResult<JSValue<E>>
}

public struct JSStaticFunction<E: JSEngine>: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let callAsFunction:
    @Sendable (
      borrowing JSInstantContext<E>, borrowing JSValue<E>, borrowing JSArguments<E>
    ) -> JSResult<JSValue<E>>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    callAsFunction:
      @escaping @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, borrowing JSArguments<E>
      ) -> JSResult<JSValue<E>>
  ) {
    self.name = name
    self.attributes = attributes
    self.callAsFunction = callAsFunction
  }
}

extension JSStaticValue {
  public var definition: JSClassStaticValueDefinition {
    JSClassStaticValueDefinition(name: name, attributes: attributes)
  }

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

extension JSStaticFunction {
  public var definition: JSClassStaticFunctionDefinition {
    JSClassStaticFunctionDefinition(name: name, attributes: attributes)
  }

  public func hostFunctionDescriptor(binding: String? = nil) -> JSHostFunctionDescriptor {
    JSHostFunctionDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      binding: binding
    )
  }
}

extension JSClassStaticValueInstallationPlan {
  package func hostPropertyDescriptor(
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

extension JSClassStaticValueDefinition {
  package func installationPlan() -> JSClassStaticValueInstallationPlan {
    JSClassStaticValueInstallationPlan(name: name, attributes: attributes)
  }
}

extension JSClassStaticFunctionDefinition {
  package func installationPlan() -> JSClassStaticFunctionInstallationPlan {
    JSClassStaticFunctionInstallationPlan(name: name, attributes: attributes)
  }
}

extension JSClassStaticFunctionInstallationPlan {
  package func hostFunctionDescriptor(binding: String? = nil) -> JSHostFunctionDescriptor {
    JSHostFunctionDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      binding: binding
    )
  }
}

package typealias JSClassHostDescriptorProjectionFlags = JSClassCallbackInstallationPlan

package func projectClassHostTypeDescriptor(
  className: String?,
  parentName: String?,
  staticValues: [JSClassStaticValueInstallationPlan],
  staticFunctions: [JSClassStaticFunctionInstallationPlan],
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

package func projectClassHostTypeDescriptor<E: JSEngine>(
  className: String?,
  parentName: String?,
  staticValues: [JSStaticValue<E>],
  staticFunctions: [JSStaticFunction<E>],
  storagePolicy: JSHostObjectStoragePolicy,
  flags: JSClassHostDescriptorProjectionFlags
) -> JSHostTypeDescriptor {
  projectClassHostTypeDescriptor(
    className: className,
    parentName: parentName,
    staticValues: staticValues.map {
      $0.definition.installationPlan()
    },
    staticFunctions: staticFunctions.map {
      $0.definition.installationPlan()
    },
    storagePolicy: storagePolicy,
    flags: flags
  )
}

private func classHostBindingName(_ className: String?, suffix: String) -> String {
  guard let className, !className.isEmpty else {
    return suffix
  }
  return "\(className).\(suffix)"
}
