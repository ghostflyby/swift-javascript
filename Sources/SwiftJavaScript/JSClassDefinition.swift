package struct JSClassDefinitionMetadataLookup<ParentClass: Sendable> {
  package let resolveParentDefinition: (ParentClass) -> JSClassDefinitionMetadata<ParentClass>?

  package init(
    resolveParentDefinition:
      @escaping (ParentClass) -> JSClassDefinitionMetadata<ParentClass>?
  ) {
    self.resolveParentDefinition = resolveParentDefinition
  }

  package func inheritanceDepth(of definition: JSClassDefinitionMetadata<ParentClass>) -> Int {
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return 1
    }
    return 1 + inheritanceDepth(of: parentDefinition)
  }

  package func exportedDefinitionCount(
    of definition: JSClassDefinitionMetadata<ParentClass>
  ) -> Int {
    inheritanceDepth(of: definition)
  }

  package func inheritedStaticValue(
    named name: String,
    in definition: JSClassDefinitionMetadata<ParentClass>
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
    in definition: JSClassDefinitionMetadata<ParentClass>
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

public protocol JSClassDefinition: Sendable {
  associatedtype Engine: JSEngine
  associatedtype ParentClass: Sendable
  associatedtype PropertyNameAccumulator

  var version: Int32 { get set }
  var attributes: JSClassAttributes { get set }
  var className: String? { get set }
  var parentClass: ParentClass? { get set }
  var staticValues: [JSStaticValue<Engine>] { get set }
  var staticFunctions: [JSStaticFunction<Engine>] { get set }
  var initialize:
    (@Sendable (borrowing JSValue<Engine>, borrowing JSInstantContext<Engine>) -> Void)?
  { get set }
  var finalize: (@Sendable (borrowing JSValue<Engine>) -> Void)? { get set }
  var hasProperty:
    (@Sendable (borrowing JSInstantContext<Engine>, borrowing JSValue<Engine>, String) -> Bool)?
  { get set }
  var getProperty:
    (
      @Sendable (borrowing JSInstantContext<Engine>, borrowing JSValue<Engine>, String)
        -> JSResult<JSValue<Engine>>
    )?
  { get set }
  var setProperty:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>, borrowing JSValue<Engine>, String,
        borrowing JSValue<Engine>
      ) -> JSValue<Engine>?
    )?
  { get set }
  var deleteProperty:
    (@Sendable (borrowing JSInstantContext<Engine>, borrowing JSValue<Engine>, String) -> Bool)?
  { get set }
  var getPropertyNames:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>, inout JSValue<Engine>, PropertyNameAccumulator
      ) -> Void
    )?
  { get set }
  var callAsFunction:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>,
        inout JSValue<Engine>,
        inout JSValue<Engine>,
        borrowing JSArguments<Engine>
      ) -> JSValue<Engine>
    )?
  { get set }
  var callAsConstructor:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>,
        inout JSValue<Engine>,
        inout JSValue<Engine>,
        borrowing JSArguments<Engine>
      ) -> JSValue<Engine>
    )?
  { get set }
  var hasInstance:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>, inout JSValue<Engine>, inout JSValue<Engine>
      ) -> Bool
    )?
  { get set }
  var convertToType:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>, inout JSValue<Engine>, JSType, inout JSValue<Engine>
      ) -> JSValue<Engine>
    )?
  { get set }
}

public struct JSClassDefinitionMetadata<ParentClass: Sendable>: Sendable {
  public var version: Int32 = 0
  public var attributes: JSClassAttributes = .init(rawValue: 0)
  public var className: String? = nil
  public var parentClass: ParentClass? = nil
  public var staticValues: [JSClassStaticValueDefinition] = []
  public var staticFunctions: [JSClassStaticFunctionDefinition] = []

  public init() {}
}

package struct JSClassDefinitionLookup<Definition: JSClassDefinition> {
  package let resolveParentDefinition: (Definition.ParentClass) -> Definition?

  package init(
    resolveParentDefinition: @escaping (Definition.ParentClass) -> Definition?
  ) {
    self.resolveParentDefinition = resolveParentDefinition
  }

  package func inheritanceDepth(of definition: Definition) -> Int {
    guard let parentClass = definition.parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return 1
    }
    return 1 + inheritanceDepth(of: parentDefinition)
  }

  package func exportedDefinitionCount(of definition: Definition) -> Int {
    inheritanceDepth(of: definition)
  }

  package func inheritedStaticValue(
    named name: String,
    in definition: Definition
  ) -> JSStaticValue<Definition.Engine>? {
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
    in definition: Definition
  ) -> JSStaticFunction<Definition.Engine>? {
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

package typealias JSEngineClassDefinitionLookup<
  E: JSEngine,
  ParentClass: Sendable,
  PropertyNameAccumulator
> = JSClassDefinitionLookup<
  JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
>

extension JSClassDefinition {
  package var callbackInstallationPlan: JSClassCallbackInstallationPlan {
    JSClassCallbackInstallationPlan(
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
  }

  public var classDefinition: JSClassDefinitionMetadata<ParentClass> {
    var definition = JSClassDefinitionMetadata<ParentClass>()
    definition.version = version
    definition.attributes = attributes
    definition.className = className
    definition.parentClass = parentClass
    definition.staticValues = staticValues.map(\.definition)
    definition.staticFunctions = staticFunctions.map(\.definition)
    return definition
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
      callbacks: callbackInstallationPlan
    )
  }

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
      (ParentClass) -> Self?
  ) -> Int {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .inheritanceDepth(of: self)
    }
  }

  public func exportedDefinitionCount(
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> Self?
  ) -> Int {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .exportedDefinitionCount(of: self)
    }
  }

  public func inheritedStaticValue(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> Self?
  ) -> JSStaticValue<Engine>? {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .inheritedStaticValue(named: name, in: self)
    }
  }

  public func inheritedStaticFunction(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> Self?
  ) -> JSStaticFunction<Engine>? {
    withoutActuallyEscaping(resolveParentDefinition) { escapingResolveParentDefinition in
      JSClassDefinitionLookup(resolveParentDefinition: escapingResolveParentDefinition)
        .inheritedStaticFunction(named: name, in: self)
    }
  }
}

public struct JSEngineClassBehavior<E: JSEngine, PropertyNameAccumulator>: Sendable {
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
}

public struct JSEngineClassDefinition<E: JSEngine, ParentClass: Sendable, PropertyNameAccumulator>:
  JSClassDefinition,
  Sendable
{
  public var definition: JSClassDefinitionMetadata<ParentClass> = .init()
  public var behavior: JSEngineClassBehavior<E, PropertyNameAccumulator> = .init()

  public init() {}

  public var version: Int32 {
    get { definition.version }
    set { definition.version = newValue }
  }

  public var attributes: JSClassAttributes {
    get { definition.attributes }
    set { definition.attributes = newValue }
  }

  public var className: String? {
    get { definition.className }
    set { definition.className = newValue }
  }

  public var parentClass: ParentClass? {
    get { definition.parentClass }
    set { definition.parentClass = newValue }
  }

  public var staticValues: [JSStaticValue<E>] {
    get { behavior.staticValues }
    set { behavior.staticValues = newValue }
  }

  public var staticFunctions: [JSStaticFunction<E>] {
    get { behavior.staticFunctions }
    set { behavior.staticFunctions = newValue }
  }

  public var initialize: (@Sendable (borrowing JSValue<E>, borrowing JSInstantContext<E>) -> Void)?
  {
    get { behavior.initialize }
    set { behavior.initialize = newValue }
  }

  public var finalize: (@Sendable (borrowing JSValue<E>) -> Void)? {
    get { behavior.finalize }
    set { behavior.finalize = newValue }
  }

  public var hasProperty:
    (@Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String) -> Bool)?
  {
    get { behavior.hasProperty }
    set { behavior.hasProperty = newValue }
  }

  public var getProperty:
    (
      @Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String)
        -> JSResult<JSValue<E>>
    )?
  {
    get { behavior.getProperty }
    set { behavior.getProperty = newValue }
  }

  public var setProperty:
    (
      @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, String,
        borrowing JSValue<E>
      )
        -> JSValue<E>?
    )?
  {
    get { behavior.setProperty }
    set { behavior.setProperty = newValue }
  }

  public var deleteProperty:
    (@Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String) -> Bool)?
  {
    get { behavior.deleteProperty }
    set { behavior.deleteProperty = newValue }
  }

  public var getPropertyNames:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, PropertyNameAccumulator
      ) -> Void
    )?
  {
    get { behavior.getPropertyNames }
    set { behavior.getPropertyNames = newValue }
  }

  public var callAsFunction:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> JSValue<E>
    )?
  {
    get { behavior.callAsFunction }
    set { behavior.callAsFunction = newValue }
  }

  public var callAsConstructor:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> JSValue<E>
    )?
  {
    get { behavior.callAsConstructor }
    set { behavior.callAsConstructor = newValue }
  }

  public var hasInstance:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, inout JSValue<E>
      )
        -> Bool
    )?
  {
    get { behavior.hasInstance }
    set { behavior.hasInstance = newValue }
  }

  public var convertToType:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, JSType, inout JSValue<E>
      )
        -> JSValue<E>
    )?
  {
    get { behavior.convertToType }
    set { behavior.convertToType = newValue }
  }
}
