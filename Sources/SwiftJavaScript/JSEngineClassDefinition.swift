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
    (@Sendable (borrowing JSEngineValue<E>, borrowing JSEngineInstantContext<E>) -> Void)? = nil

  public var finalize: (@Sendable (borrowing JSEngineValue<E>) -> Void)? = nil

  public var hasProperty:
    (@Sendable (borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, String) -> Bool)? =
      nil

  public var getProperty:
    (
      @Sendable (borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, String)
        -> JSResult<JSEngineValue<E>>
    )? =
      nil

  public var setProperty:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, String,
        borrowing JSEngineValue<E>
      )
        -> JSEngineValue<E>?
    )? =
      nil

  public var deleteProperty:
    (@Sendable (borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, String) -> Bool)? =
      nil

  public var getPropertyNames:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, inout JSEngineValue<E>, PropertyNameAccumulator
      ) -> Void
    )? =
      nil

  public var callAsFunction:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>,
        inout JSEngineValue<E>,
        inout JSEngineValue<E>,
        borrowing JSArguments<E>
      ) -> JSEngineValue<E>
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>,
        inout JSEngineValue<E>,
        inout JSEngineValue<E>,
        borrowing JSArguments<E>
      ) -> JSEngineValue<E>
    )? = nil

  public var hasInstance:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, inout JSEngineValue<E>, inout JSEngineValue<E>
      )
        -> Bool
    )? =
      nil

  public var convertToType:
    (
      @Sendable (
        borrowing JSEngineInstantContext<E>, inout JSEngineValue<E>, JSType, inout JSEngineValue<E>
      )
        -> JSEngineValue<E>
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
}
