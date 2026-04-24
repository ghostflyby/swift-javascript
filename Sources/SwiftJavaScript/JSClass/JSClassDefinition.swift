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
  var hasDynamicPropertyGetter: Bool { get }
  var hasDynamicPropertySetter: Bool { get }
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
  var hasCallAsFunction: Bool { get }
  var hasConstructor: Bool { get }
  var hasInstance:
    (
      @Sendable (
        borrowing JSInstantContext<Engine>, inout JSValue<Engine>, inout JSValue<Engine>
      ) -> Bool
    )?
  { get set }
  var hasConvertToType: Bool { get }

  @_lifetime(immortal)
  func dynamicPropertyValue(
    in context: borrowing JSInstantContext<Engine>,
    on thisValue: borrowing JSValue<Engine>,
    forKey key: String
  ) -> JSResult<JSValue<Engine>>

  @_lifetime(immortal)
  func setDynamicPropertyException(
    in context: borrowing JSInstantContext<Engine>,
    on thisValue: borrowing JSValue<Engine>,
    forKey key: String,
    to newValue: borrowing JSValue<Engine>
  ) -> JSValue<Engine>?

  @_lifetime(immortal)
  func callAsFunctionValue(
    in context: borrowing JSInstantContext<Engine>,
    function: inout JSValue<Engine>,
    this thisValue: inout JSValue<Engine>,
    arguments: borrowing JSArguments<Engine>
  ) -> JSValue<Engine>?

  @_lifetime(immortal)
  func callAsConstructorValue(
    in context: borrowing JSInstantContext<Engine>,
    constructor: inout JSValue<Engine>,
    this thisValue: inout JSValue<Engine>,
    arguments: borrowing JSArguments<Engine>
  ) -> JSValue<Engine>?

  @_lifetime(immortal)
  func convertToTypeValue(
    in context: borrowing JSInstantContext<Engine>,
    value: inout JSValue<Engine>,
    type: JSType,
    exception: inout JSValue<Engine>
  ) -> JSValue<Engine>?
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
      hasDynamicPropertyGetter: hasDynamicPropertyGetter,
      hasDynamicPropertySetter: hasDynamicPropertySetter,
      hasDynamicPropertyHas: hasProperty != nil,
      hasDynamicPropertyDelete: deleteProperty != nil,
      hasPropertyEnumerator: getPropertyNames != nil,
      hasCallAsFunction: hasCallAsFunction,
      hasConstructor: hasConstructor,
      hasHasInstance: hasInstance != nil,
      hasConvertToType: hasConvertToType
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

  package func hasDynamicProperty(
    in context: borrowing JSInstantContext<Engine>,
    on thisValue: borrowing JSValue<Engine>,
    forKey key: String
  ) -> Bool {
    hasProperty?(context, thisValue, key) ?? false
  }

  package func deleteDynamicProperty(
    in context: borrowing JSInstantContext<Engine>,
    on thisValue: borrowing JSValue<Engine>,
    forKey key: String
  ) -> Bool {
    deleteProperty?(context, thisValue, key) ?? false
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
    (@Sendable (E.ContextHandle, JSValueHandle<E>, String) -> (Bool, JSValueHandle<E>))? =
      nil

  public var setProperty:
    (
      @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, String,
        borrowing JSValue<E>
      )
        -> sending JSValueHandle<E>?
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
      ) -> sending JSValueHandle<E>
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> sending JSValueHandle<E>
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
        -> sending JSValueHandle<E>
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
  private var storedGetProperty:
    (
      @Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String)
        -> sending JSResult<JSValue<E>>
    )? = nil
  private var storedSetProperty:
    (
      @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, String,
        borrowing JSValue<E>
      )
        -> sending JSValue<E>?
    )? = nil
  private var storedCallAsFunction:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> sending JSValue<E>
    )? = nil
  private var storedCallAsConstructor:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> sending JSValue<E>
    )? = nil
  private var storedConvertToType:
    (
      @Sendable (
        borrowing JSInstantContext<E>, inout JSValue<E>, JSType, inout JSValue<E>
      )
        -> sending JSValue<E>
    )? = nil

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

  public var hasDynamicPropertyGetter: Bool {
    behavior.getProperty != nil
  }

  public var getProperty:
    (
      @Sendable (borrowing JSInstantContext<E>, borrowing JSValue<E>, String)
        -> sending JSResult<JSValue<E>>
    )?
  {
    get { storedGetProperty }
    set {
      storedGetProperty = newValue
      guard let newValue else {
        behavior.getProperty = nil
        return
      }
      behavior.getProperty = { contextHandle, thisHandle, key in
        let context = JSInstantContext<E>(handle: contextHandle)
        let thisValue = JSValue<E>(handleValue: thisHandle)
        let result = retainResult(newValue(context, thisValue, key))
        thisValue.discard()
        switch consume result {
        case .value(let value):
          return (false, value.takeHandle())
        case .exception(let exception):
          return (true, exception.takeHandle())
        }
      }
    }
  }

  public var setProperty:
    (
      @Sendable (
        borrowing JSInstantContext<E>, borrowing JSValue<E>, String,
        borrowing JSValue<E>
      )
        -> sending JSValue<E>?
    )?
  {
    get { storedSetProperty }
    set {
      storedSetProperty = newValue
      guard let newValue else {
        behavior.setProperty = nil
        return
      }
      behavior.setProperty = { context, thisValue, key, propertyValue in
        guard let exception = newValue(context, thisValue, key, propertyValue) else {
          return nil
        }
        return JSValue(retaining: exception).takeHandle()
      }
    }
  }

  public var hasDynamicPropertySetter: Bool {
    behavior.setProperty != nil
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
      ) -> sending JSValue<E>
    )?
  {
    get { storedCallAsFunction }
    set {
      storedCallAsFunction = newValue
      guard let newValue else {
        behavior.callAsFunction = nil
        return
      }
      behavior.callAsFunction = { context, function, thisValue, arguments in
        let value = newValue(context, &function, &thisValue, arguments)
        return JSValue(retaining: value).takeHandle()
      }
    }
  }

  public var hasCallAsFunction: Bool {
    behavior.callAsFunction != nil
  }

  public var callAsConstructor:
    (
      @Sendable (
        borrowing JSInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> sending JSValue<E>
    )?
  {
    get { storedCallAsConstructor }
    set {
      storedCallAsConstructor = newValue
      guard let newValue else {
        behavior.callAsConstructor = nil
        return
      }
      behavior.callAsConstructor = { context, constructor, thisValue, arguments in
        let value = newValue(context, &constructor, &thisValue, arguments)
        return JSValue(retaining: value).takeHandle()
      }
    }
  }

  public var hasConstructor: Bool {
    behavior.callAsConstructor != nil
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
        -> sending JSValue<E>
    )?
  {
    get { storedConvertToType }
    set {
      storedConvertToType = newValue
      guard let newValue else {
        behavior.convertToType = nil
        return
      }
      behavior.convertToType = { context, value, type, exception in
        let converted = newValue(context, &value, type, &exception)
        return JSValue(retaining: converted).takeHandle()
      }
    }
  }

  public var hasConvertToType: Bool {
    behavior.convertToType != nil
  }

  @_lifetime(immortal)
  public func dynamicPropertyValue(
    in context: borrowing JSInstantContext<E>,
    on thisValue: borrowing JSValue<E>,
    forKey key: String
  ) -> JSResult<JSValue<E>> {
    guard let getProperty = behavior.getProperty else {
      guard let handle = E.makeUndefinedValueHandle(context.driverContextHandle) else {
        preconditionFailure("JSEngineClassDefinition could not create undefined handle")
      }
      return .value(JSValue(handleValue: handle))
    }
    let result = getProperty(context.driverContextHandle, thisValue.borrowHandle(), key)
    if result.0 {
      return .exception(JSValue(handleValue: result.1))
    }
    return .value(JSValue(handleValue: result.1))
  }

  @_lifetime(immortal)
  public func setDynamicPropertyException(
    in context: borrowing JSInstantContext<E>,
    on thisValue: borrowing JSValue<E>,
    forKey key: String,
    to newValue: borrowing JSValue<E>
  ) -> JSValue<E>? {
    guard let handle = behavior.setProperty?(context, thisValue, key, newValue) else {
      return nil
    }
    return JSValue(handleValue: handle)
  }

  @_lifetime(immortal)
  public func callAsFunctionValue(
    in context: borrowing JSInstantContext<E>,
    function: inout JSValue<E>,
    this thisValue: inout JSValue<E>,
    arguments: borrowing JSArguments<E>
  ) -> JSValue<E>? {
    guard let callAsFunction = behavior.callAsFunction else {
      return nil
    }
    return JSValue(handleValue: callAsFunction(context, &function, &thisValue, arguments))
  }

  @_lifetime(immortal)
  public func callAsConstructorValue(
    in context: borrowing JSInstantContext<E>,
    constructor: inout JSValue<E>,
    this thisValue: inout JSValue<E>,
    arguments: borrowing JSArguments<E>
  ) -> JSValue<E>? {
    guard let callAsConstructor = behavior.callAsConstructor else {
      return nil
    }
    return JSValue(handleValue: callAsConstructor(context, &constructor, &thisValue, arguments))
  }

  @_lifetime(immortal)
  public func convertToTypeValue(
    in context: borrowing JSInstantContext<E>,
    value: inout JSValue<E>,
    type: JSType,
    exception: inout JSValue<E>
  ) -> JSValue<E>? {
    guard let convertToType = behavior.convertToType else {
      return nil
    }
    return JSValue(handleValue: convertToType(context, &value, type, &exception))
  }
}
