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

  public var staticValues: [JSEngineStaticValue<E>] = []

  public var staticFunctions: [JSEngineStaticFunction<E>] = []

  public var initialize:
    (@Sendable (borrowing JSValue<E>, borrowing JSEngineInstantContext<E>) -> Void)? = nil

  public var finalize: (@Sendable (borrowing JSValue<E>) -> Void)? = nil

  public var hasProperty:
    (@Sendable (borrowing JSEngineInstantContext<E>, borrowing JSValue<E>, String) -> Bool)? =
      nil

  public var getProperty:
    (
      @Sendable (borrowing JSEngineInstantContext<E>, borrowing JSValue<E>, String)
        -> JSResult<JSValue<E>>
    )? =
      nil

  public var setProperty:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSValue<E>, String,
        borrowing JSValue<E>
      )
        -> JSValue<E>?
    )? =
      nil

  public var deleteProperty:
    (@Sendable (borrowing JSEngineInstantContext<E>, borrowing JSValue<E>, String) -> Bool)? =
      nil

  public var getPropertyNames:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, inout JSValue<E>, PropertyNameAccumulator
      ) -> Void
    )? =
      nil

  public var callAsFunction:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> JSValue<E>
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>,
        inout JSValue<E>,
        inout JSValue<E>,
        borrowing JSArguments<E>
      ) -> JSValue<E>
    )? = nil

  public var hasInstance:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, inout JSValue<E>, inout JSValue<E>
      )
        -> Bool
    )? =
      nil

  public var convertToType:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, inout JSValue<E>, JSType, inout JSValue<E>
      )
        -> JSValue<E>
    )? =
      nil

  public init() {}

  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer,
    parentName: String?
  ) -> JSHostTypeDescriptor {
    projectClassHostTypeDescriptor(
      className: className,
      parentName: parentName,
      staticValues: staticValues,
      staticFunctions: staticFunctions,
      storagePolicy: storagePolicy,
      flags: JSClassHostDescriptorProjectionFlags(
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
    guard let parentClass,
      let parentDefinition = resolveParentDefinition(parentClass)
    else {
      return 1
    }
    return 1 + parentDefinition.inheritanceDepth(resolvingParentDefinition: resolveParentDefinition)
  }

  public func exportedDefinitionCount(
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> Int {
    inheritanceDepth(resolvingParentDefinition: resolveParentDefinition)
  }

  public func inheritedStaticValue(
    named name: String,
    resolvingParentDefinition resolveParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> JSEngineStaticValue<E>? {
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
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) -> JSEngineStaticFunction<E>? {
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
}
