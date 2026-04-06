package struct JSClassStaticValueInstallationPlan: Sendable {
  package let name: String
  package let attributes: JSPropertyAttributes
}

package struct JSClassStaticFunctionInstallationPlan: Sendable {
  package let name: String
  package let attributes: JSPropertyAttributes
}

package struct JSClassCallbackInstallationPlan: Sendable {
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
}

package struct JSClassDefinitionInstallationPlan<ParentClass: Sendable>: Sendable {
  package let version: Int32
  package let attributes: JSClassAttributes
  package let className: String?
  package let parentClass: ParentClass?
  package let staticValues: [JSClassStaticValueInstallationPlan]
  package let staticFunctions: [JSClassStaticFunctionInstallationPlan]
  package let callbacks: JSClassCallbackInstallationPlan
}

public struct JSClassDefinition<E: JSEngine, ParentClass: Sendable, PropertyNameAccumulator>:
  Sendable
{

  public var version: Int32 = 0

  public var attributes: JSClassAttributes = .init(rawValue: 0)

  public var className: String? {
    didSet {
      if let className {
        _className = className.utf8CString
      } else {
        _className = nil
      }
    }
  }

  private var _className: ContiguousArray<CChar>? = nil

  public var parentClass: ParentClass? = nil

  public var staticValues: [JSStaticValue<E>] = []

  public var staticFunctions: [JSStaticFunction<E>] = []

  public var initialize:
    (@Sendable (borrowing JSValue<E>, borrowing JSInstantContext<E>) -> Void)? = nil

  public var finalize: (@Sendable (borrowing JSValue<E>) -> Void)? = nil

  public var hasProperty:
    (@Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String) -> Bool)? =
      nil

  public var getProperty:
    (
      @Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String)
        -> JSResult<JSValue<E>>
    )? =
      nil

  public var setProperty:
    (
      @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, String,
        borrowing JSValue<E>
      )
        -> JSValue<E>?
    )? =
      nil

  public var deleteProperty:
    (@Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String) -> Bool)? =
      nil

  public var getPropertyNames:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, PropertyNameAccumulator
      ) -> Void
    )? =
      nil

  public var callAsFunction:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> JSValue<E>
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> JSValue<E>
    )? = nil

  public var hasInstance:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, inout JSValue<E>
      )
        -> Bool
    )? =
      nil

  public var convertToType:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, JSType, inout JSValue<E>
      )
        -> JSValue<E>
    )? =
      nil

  public init() {}

  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer,
    parentName: String?
  ) -> JSHostTypeDescriptor {
    let plan = installationPlan()
    return projectClassHostTypeDescriptor(
      className: plan.className,
      parentName: parentName,
      staticValues: plan.staticValues,
      staticFunctions: plan.staticFunctions,
      storagePolicy: storagePolicy,
      flags: plan.callbacks
    )
  }

  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer,
    resolvingParentNameWith resolveParentName: (ParentClass) -> String?
  ) -> JSHostTypeDescriptor {
    hostTypeDescriptor(
      storagePolicy: storagePolicy,
      parentName: parentClass.flatMap { resolveParentName($0) }
    )
  }

  public func inheritanceDepth(
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> Int {
    guard let parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return 1
    }
    return 1 + parentDefinition.inheritanceDepth(resolvingParentDefinition: resolveParentDefinition)
  }

  public func exportedDefinitionCount(
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> Int {
    inheritanceDepth(resolvingParentDefinition: resolveParentDefinition)
  }

  public func inheritedStaticValue(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> JSStaticValue<E>? {
    if let value = staticValues.first(where: { $0.name == name }) {
      return value
    }
    guard let parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return nil
    }
    return parentDefinition.inheritedStaticValue(
      named: name,
      resolvingParentDefinition: resolveParentDefinition
    )
  }

  public func inheritedStaticFunction(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> JSStaticFunction<E>? {
    if let function = staticFunctions.first(where: { $0.name == name }) {
      return function
    }
    guard let parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return nil
    }
    return parentDefinition.inheritedStaticFunction(
      named: name,
      resolvingParentDefinition: resolveParentDefinition
    )
  }

  package func installationPlan() -> JSClassDefinitionInstallationPlan<ParentClass> {
    JSClassDefinitionInstallationPlan(
      version: version,
      attributes: attributes,
      className: className,
      parentClass: parentClass,
      staticValues: staticValues.map {
        JSClassStaticValueInstallationPlan(name: $0.name, attributes: $0.attributes)
      },
      staticFunctions: staticFunctions.map {
        JSClassStaticFunctionInstallationPlan(name: $0.name, attributes: $0.attributes)
      },
      callbacks: JSClassCallbackInstallationPlan(
        hasInitializer: initialize != nil,
        hasFinalizer: finalize != nil,
        hasDynamicPropertyGetter: getProperty != nil,
        hasDynamicPropertySetter: setProperty != nil,
        hasDynamicPropertyHas: hasProperty != nil,
        hasDynamicPropertyDelete: deleteProperty != nil,
        hasPropertyEnumerator: getPropertyNames != nil,
        hasCallAsFunction: callAsFunction != nil,
        hasConstructor: callAsConstructor != nil,
        hasHasInstance: hasInstance != nil,
        hasConvertToType: convertToType != nil
      )
    )
  }
}
