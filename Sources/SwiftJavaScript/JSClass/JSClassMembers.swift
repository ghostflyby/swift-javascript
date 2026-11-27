public protocol JSStaticValueDefinition: Sendable {
  associatedtype Context: JSContext

  var name: String { get }
  var attributes: JSPropertyAttributes { get }
  var getProperty:
    @Sendable (borrowing Context.InstantContext, borrowing Context.Value)
      -> JSResult<Context.Value>
  { get }
  var setProperty:
    @Sendable (
      borrowing Context.InstantContext, borrowing Context.Value, borrowing Context.Value
    ) -> JSResult<Context.Value>
  { get }
}

public protocol JSStaticFunctionDefinition: Sendable {
  associatedtype Context: JSContext

  var name: String { get }
  var attributes: JSPropertyAttributes { get }
  var callAsFunction:
    @Sendable (
      borrowing Context.InstantContext, borrowing Context.Value, borrowing Context.Arguments
    ) -> JSResult<Context.Value>
  { get }
}

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

public struct JSStaticValue<E: JSContext>: JSStaticValueDefinition, Sendable {
  public typealias Context = E

  public let name: String
  public let attributes: JSPropertyAttributes
  public let getProperty:
    @Sendable (borrowing E.InstantContext, borrowing E.Value)
      -> JSResult<E.Value>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    getProperty:
      @escaping @Sendable (
        borrowing E.InstantContext, borrowing E.Value
      ) -> JSResult<E.Value>,
    setProperty:
      @escaping @Sendable (
        borrowing E.InstantContext, borrowing E.Value, borrowing E.Value
      ) -> JSResult<E.Value>
  ) {
    self.name = name
    self.attributes = attributes
    self.getProperty = getProperty
    self.setProperty = setProperty
  }
  public let setProperty:
    @Sendable (
      borrowing E.InstantContext, borrowing E.Value, borrowing E.Value
    ) -> JSResult<E.Value>
}

public struct JSStaticFunction<E: JSContext>: JSStaticFunctionDefinition, Sendable {
  public typealias Context = E

  public let name: String
  public let attributes: JSPropertyAttributes
  public let callAsFunction:
    @Sendable (
      borrowing E.InstantContext, borrowing E.Value, borrowing E.Arguments
    ) -> JSResult<E.Value>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    callAsFunction:
      @escaping @Sendable (
        borrowing E.InstantContext, borrowing E.Value, borrowing E.Arguments
      ) -> JSResult<E.Value>
  ) {
    self.name = name
    self.attributes = attributes
    self.callAsFunction = callAsFunction
  }
}

extension JSStaticValueDefinition {
  public var definition: JSClassStaticValueDefinition {
    JSClassStaticValueDefinition(name: name, attributes: attributes)
  }

  package func propertyValue(
    in context: borrowing Context.InstantContext,
    on thisValue: borrowing Context.Value
  ) -> JSResult<Context.Value> {
    getProperty(context, thisValue)
  }

  package func setPropertyException(
    in context: borrowing Context.InstantContext,
    on thisValue: borrowing Context.Value,
    to newValue: borrowing Context.Value
  ) -> Context.Value? {
    takeExceptionValue(setProperty(context, thisValue, newValue))
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

extension JSStaticFunctionDefinition {
  public var definition: JSClassStaticFunctionDefinition {
    JSClassStaticFunctionDefinition(name: name, attributes: attributes)
  }

  package func callResult(
    in context: borrowing Context.InstantContext,
    on thisValue: borrowing Context.Value,
    with arguments: borrowing Context.Arguments
  ) -> JSResult<Context.Value> {
    callAsFunction(context, thisValue, arguments)
  }

  public func hostFunctionDescriptor(binding: String? = nil) -> JSHostFunctionDescriptor {
    JSHostFunctionDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      binding: binding
    )
  }
}

extension JSClassStaticValueDefinition {
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

extension JSClassStaticFunctionDefinition {
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
  staticValues: [JSClassStaticValueDefinition],
  staticFunctions: [JSClassStaticFunctionDefinition],
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

package func projectClassHostTypeDescriptor<
  StaticValues: Sequence,
  StaticFunctions: Sequence
>(
  className: String?,
  parentName: String?,
  staticValues: StaticValues,
  staticFunctions: StaticFunctions,
  storagePolicy: JSHostObjectStoragePolicy,
  flags: JSClassHostDescriptorProjectionFlags
) -> JSHostTypeDescriptor
where
  StaticValues.Element: JSStaticValueDefinition,
  StaticFunctions.Element: JSStaticFunctionDefinition,
  StaticValues.Element.Context == StaticFunctions.Element.Context
{
  projectClassHostTypeDescriptor(
    className: className,
    parentName: parentName,
    staticValues: staticValues.map(\.definition),
    staticFunctions: staticFunctions.map(\.definition),
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
