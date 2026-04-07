package struct JSClassDefinitionLookup<ParentClass: Sendable> {
  package let resolveParentDefinition: (ParentClass) -> JSClassDefinition<ParentClass>?

  package init(
    resolveParentDefinition: @escaping (ParentClass) -> JSClassDefinition<ParentClass>?
  ) {
    self.resolveParentDefinition = resolveParentDefinition
  }

  package func inheritanceDepth(of definition: JSClassDefinition<ParentClass>) -> Int {
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return 1
    }
    return 1 + inheritanceDepth(of: parentDefinition)
  }

  package func exportedDefinitionCount(of definition: JSClassDefinition<ParentClass>) -> Int {
    inheritanceDepth(of: definition)
  }

  package func inheritedStaticValue(
    named name: String,
    in definition: JSClassDefinition<ParentClass>
  ) -> JSClassStaticValueDefinition? {
    if let value = definition.staticValues.first(where: { $0.name == name }) {
      return value
    }
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return nil
    }
    return inheritedStaticValue(named: name, in: parentDefinition)
  }

  package func inheritedStaticFunction(
    named name: String,
    in definition: JSClassDefinition<ParentClass>
  ) -> JSClassStaticFunctionDefinition? {
    if let function = definition.staticFunctions.first(where: { $0.name == name }) {
      return function
    }
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return nil
    }
    return inheritedStaticFunction(named: name, in: parentDefinition)
  }
}

package struct JSEngineClassDefinitionLookup<
  E: JSEngine,
  ParentClass: Sendable,
  PropertyNameAccumulator
> {
  package let resolveParentDefinition:
    (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?

  package init(
    resolveParentDefinition:
      @escaping (ParentClass) -> JSEngineClassDefinition<
        E, ParentClass, PropertyNameAccumulator
      >?
  ) {
    self.resolveParentDefinition = resolveParentDefinition
  }

  package func inheritanceDepth(
    of definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
  ) -> Int {
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return 1
    }
    return 1 + inheritanceDepth(of: parentDefinition)
  }

  package func exportedDefinitionCount(
    of definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
  ) -> Int {
    inheritanceDepth(of: definition)
  }

  package func inheritedStaticValue(
    named name: String,
    in definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
  ) -> JSStaticValue<E>? {
    if let value = definition.staticValues.first(where: { $0.name == name }) {
      return value
    }
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return nil
    }
    return inheritedStaticValue(named: name, in: parentDefinition)
  }

  package func inheritedStaticFunction(
    named name: String,
    in definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
  ) -> JSStaticFunction<E>? {
    if let function = definition.staticFunctions.first(where: { $0.name == name }) {
      return function
    }
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return nil
    }
    return inheritedStaticFunction(named: name, in: parentDefinition)
  }
}

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

public struct JSClassDefinition<ParentClass: Sendable>: Sendable {
  public var version: Int32 = 0
  public var attributes: JSClassAttributes = .init(rawValue: 0)
  public var className: String? = nil
  public var parentClass: ParentClass? = nil
  public var staticValues: [JSClassStaticValueDefinition] = []
  public var staticFunctions: [JSClassStaticFunctionDefinition] = []

  public init() {}
}

public struct JSEngineClassDefinition<E: JSEngine, ParentClass: Sendable, PropertyNameAccumulator>:
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
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> Int {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSEngineClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .inheritanceDepth(of: self)
    }
  }

  public func exportedDefinitionCount(
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> Int {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSEngineClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .exportedDefinitionCount(of: self)
    }
  }

  public func inheritedStaticValue(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> JSStaticValue<E>? {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSEngineClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .inheritedStaticValue(named: name, in: self)
    }
  }

  public func inheritedStaticFunction(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> JSStaticFunction<E>? {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSEngineClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .inheritedStaticFunction(named: name, in: self)
    }
  }

  package func installationPlan() -> JSClassDefinitionInstallationPlan<ParentClass> {
    let definition = classDefinition
    return JSClassDefinitionInstallationPlan(
      version: definition.version,
      attributes: definition.attributes,
      className: definition.className,
      parentClass: definition.parentClass,
      staticValues: definition.staticValues.map { $0.installationPlan() },
      staticFunctions: definition.staticFunctions.map { $0.installationPlan() },
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

  public var classDefinition: JSClassDefinition<ParentClass> {
    var definition = JSClassDefinition<ParentClass>()
    definition.version = version
    definition.attributes = attributes
    definition.className = className
    definition.parentClass = parentClass
    definition.staticValues = staticValues.map(\.definition)
    definition.staticFunctions = staticFunctions.map(\.definition)
    return definition
  }
}
