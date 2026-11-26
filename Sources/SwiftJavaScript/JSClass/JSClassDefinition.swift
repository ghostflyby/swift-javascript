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

public protocol JSClassDefinition: Sendable {
  associatedtype Engine: JSEngineClassBridgeDriver
  associatedtype ParentClass: Sendable
  associatedtype PropertyNameAccumulator

  var version: Int32 { get set }
  var attributes: JSClassAttributes { get set }
  var className: String? { get set }
  var parentClass: ParentClass? { get set }
  var staticValues: [JSStaticValue<Engine>] { get set }
  var staticFunctions: [JSStaticFunction<Engine>] { get set }
  var initialize: (@Sendable (borrowing Engine.Value, borrowing Engine.InstantContext) -> Void)?
  { get set }
  var finalize: (@Sendable (borrowing Engine.Value) -> Void)? { get set }
  var hasProperty:
    (
      @Sendable (borrowing Engine.InstantContext, borrowing Engine.Value, String)
        -> Bool
    )?
  { get set }
  var getProperty:
    (
      @Sendable (borrowing Engine.InstantContext, borrowing Engine.Value, String)
        -> JSResult<Engine.Value>
    )?
  { get set }
  var setProperty:
    (
      @Sendable (
        borrowing Engine.InstantContext, borrowing Engine.Value, String,
        borrowing Engine.Value
      ) -> Engine.Value?
    )?
  { get set }
  var deleteProperty:
    (
      @Sendable (borrowing Engine.InstantContext, borrowing Engine.Value, String)
        -> Bool
    )?
  { get set }
  var getPropertyNames:
    (
      @Sendable (
        borrowing Engine.InstantContext, inout Engine.Value,
        PropertyNameAccumulator
      ) -> Void
    )?
  { get set }
  var callAsFunction:
    (
      @Sendable (
        borrowing Engine.InstantContext,
        inout Engine.Value,
        inout Engine.Value,
        borrowing Engine.Arguments
      ) -> Engine.Value
    )?
  { get set }
  var callAsConstructor:
    (
      @Sendable (
        borrowing Engine.InstantContext,
        inout Engine.Value,
        inout Engine.Value,
        borrowing Engine.Arguments
      ) -> Engine.Value
    )?
  { get set }
  var hasInstance:
    (
      @Sendable (
        borrowing Engine.InstantContext, inout Engine.Value,
        inout Engine.Value
      ) -> Bool
    )?
  { get set }
  var convertToType:
    (
      @Sendable (
        borrowing Engine.InstantContext, inout Engine.Value, JSType,
        inout Engine.Value
      ) -> Engine.Value
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

public struct JSClassParentDescriptor<
  E: JSEngineClassBridgeDriver,
  PropertyNameAccumulator
>: Sendable, Hashable {
  private let typeID: ObjectIdentifier
  private let definitionProvider:
    @Sendable () -> JSEngineClassDefinition<
      E,
      JSClassParentDescriptor<E, PropertyNameAccumulator>,
      PropertyNameAccumulator
    >
  private let classProvider: @Sendable (borrowing E.InstantContext) -> E.Class

  package init(
    typeID: ObjectIdentifier,
    definitionProvider:
      @escaping @Sendable () -> JSEngineClassDefinition<
        E,
        JSClassParentDescriptor<E, PropertyNameAccumulator>,
        PropertyNameAccumulator
      >,
    classProvider: @escaping @Sendable (borrowing E.InstantContext) -> E.Class
  ) {
    self.typeID = typeID
    self.definitionProvider = definitionProvider
    self.classProvider = classProvider
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.typeID == rhs.typeID
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(typeID)
  }

  public func definition() -> JSEngineClassDefinition<
    E,
    JSClassParentDescriptor<E, PropertyNameAccumulator>,
    PropertyNameAccumulator
  > {
    definitionProvider()
  }

  public func jsClass(in context: borrowing E.InstantContext) -> E.Class {
    classProvider(context)
  }
}

extension JSClassParentDescriptor
where E: JSEngineClassBridgeDriver, PropertyNameAccumulator == E.ClassPropertyNameAccumulator {
  public static func `for`<Parent: JSClassValueConvertible>(
    _ parent: Parent.Type
  ) -> Self
  where
    Parent.Engine == E,
    Parent.ParentClass == Self,
    Parent.PropertyNameAccumulator == PropertyNameAccumulator,
    Parent.ClassDefinition == JSEngineClassDefinition<E, Self, PropertyNameAccumulator>
  {
    _ = parent
    return Self(
      typeID: ObjectIdentifier(Parent.self),
      definitionProvider: { Parent.jsClassDefinition },
      classProvider: { Parent.jsClass(in: $0) }
    )
  }
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
  E: JSEngineClassBridgeDriver,
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

  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer,
    parentName: String?
  ) -> JSHostTypeDescriptor {
    let definition = classDefinition
    return projectClassHostTypeDescriptor(
      className: definition.className,
      parentName: parentName,
      staticValues: definition.staticValues,
      staticFunctions: definition.staticFunctions,
      storagePolicy: storagePolicy,
      flags: callbackInstallationPlan
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

  package func dynamicPropertyValue(
    in context: borrowing Engine.InstantContext,
    on thisValue: borrowing Engine.Value,
    forKey key: String
  ) -> JSResult<Engine.Value> {
    getProperty?(context, thisValue, key)
      ?? .value(context.persist(context.makeUndefined()))
  }

  package func setDynamicPropertyException(
    in context: borrowing Engine.InstantContext,
    on thisValue: borrowing Engine.Value,
    forKey key: String,
    to newValue: borrowing Engine.Value
  ) -> Engine.Value? {
    setProperty?(context, thisValue, key, newValue)
  }

  package func hasDynamicProperty(
    in context: borrowing Engine.InstantContext,
    on thisValue: borrowing Engine.Value,
    forKey key: String
  ) -> Bool {
    hasProperty?(context, thisValue, key) ?? false
  }

  package func deleteDynamicProperty(
    in context: borrowing Engine.InstantContext,
    on thisValue: borrowing Engine.Value,
    forKey key: String
  ) -> Bool {
    deleteProperty?(context, thisValue, key) ?? false
  }
}

public struct JSEngineClassBehavior<E: JSEngineClassBridgeDriver, PropertyNameAccumulator>: Sendable
{
  public var staticValues: [JSStaticValue<E>] = []

  public var staticFunctions: [JSStaticFunction<E>] = []

  public var initialize: (@Sendable (borrowing E.Value, borrowing E.InstantContext) -> Void)? = nil

  public var finalize: (@Sendable (borrowing E.Value) -> Void)? = nil

  public var hasProperty:
    (@Sendable (borrowing E.InstantContext, borrowing E.Value, String) -> Bool)? =
      nil

  public var getProperty:
    (
      @Sendable (borrowing E.InstantContext, borrowing E.Value, String)
        -> JSResult<E.Value>
    )? =
      nil

  public var setProperty:
    (
      @Sendable (
        borrowing E.InstantContext, borrowing E.Value, String,
        borrowing E.Value
      )
        -> E.Value?
    )? =
      nil

  public var deleteProperty:
    (@Sendable (borrowing E.InstantContext, borrowing E.Value, String) -> Bool)? =
      nil

  public var getPropertyNames:
    (
      @Sendable (
        borrowing E.InstantContext, inout E.Value, PropertyNameAccumulator
      ) -> Void
    )? =
      nil

  public var callAsFunction:
    (
      @Sendable (
        borrowing E.InstantContext,
        inout E.Value,
        inout E.Value,
        borrowing E.Arguments
      ) -> E.Value
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (
        borrowing E.InstantContext,
        inout E.Value,
        inout E.Value,
        borrowing E.Arguments
      ) -> E.Value
    )? = nil

  public var hasInstance:
    (
      @Sendable (
        borrowing E.InstantContext, inout E.Value, inout E.Value
      )
        -> Bool
    )? =
      nil

  public var convertToType:
    (
      @Sendable (
        borrowing E.InstantContext, inout E.Value, JSType, inout E.Value
      )
        -> E.Value
    )? =
      nil

  public init() {}
}

public struct JSEngineClassDefinition<
  E: JSEngineClassBridgeDriver, ParentClass: Sendable, PropertyNameAccumulator
>:
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

  public var initialize: (@Sendable (borrowing E.Value, borrowing E.InstantContext) -> Void)?
  {
    get { behavior.initialize }
    set { behavior.initialize = newValue }
  }

  public var finalize: (@Sendable (borrowing E.Value) -> Void)? {
    get { behavior.finalize }
    set { behavior.finalize = newValue }
  }

  public var hasProperty:
    (@Sendable (borrowing E.InstantContext, borrowing E.Value, String) -> Bool)?
  {
    get { behavior.hasProperty }
    set { behavior.hasProperty = newValue }
  }

  public var getProperty:
    (
      @Sendable (borrowing E.InstantContext, borrowing E.Value, String)
        -> JSResult<E.Value>
    )?
  {
    get { behavior.getProperty }
    set { behavior.getProperty = newValue }
  }

  public var setProperty:
    (
      @Sendable (
        borrowing E.InstantContext, borrowing E.Value, String,
        borrowing E.Value
      )
        -> E.Value?
    )?
  {
    get { behavior.setProperty }
    set { behavior.setProperty = newValue }
  }

  public var deleteProperty:
    (@Sendable (borrowing E.InstantContext, borrowing E.Value, String) -> Bool)?
  {
    get { behavior.deleteProperty }
    set { behavior.deleteProperty = newValue }
  }

  public var getPropertyNames:
    (
      @Sendable (
        borrowing E.InstantContext, inout E.Value, PropertyNameAccumulator
      ) -> Void
    )?
  {
    get { behavior.getPropertyNames }
    set { behavior.getPropertyNames = newValue }
  }

  public var callAsFunction:
    (
      @Sendable (
        borrowing E.InstantContext,
        inout E.Value,
        inout E.Value,
        borrowing E.Arguments
      ) -> E.Value
    )?
  {
    get { behavior.callAsFunction }
    set { behavior.callAsFunction = newValue }
  }

  public var callAsConstructor:
    (
      @Sendable (
        borrowing E.InstantContext,
        inout E.Value,
        inout E.Value,
        borrowing E.Arguments
      ) -> E.Value
    )?
  {
    get { behavior.callAsConstructor }
    set { behavior.callAsConstructor = newValue }
  }

  public var hasInstance:
    (
      @Sendable (
        borrowing E.InstantContext, inout E.Value, inout E.Value
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
        borrowing E.InstantContext, inout E.Value, JSType, inout E.Value
      )
        -> E.Value
    )?
  {
    get { behavior.convertToType }
    set { behavior.convertToType = newValue }
  }
}
