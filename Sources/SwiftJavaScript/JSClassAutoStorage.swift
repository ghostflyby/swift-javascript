package final class JSClassAutoNativeClassBacking<
  E: JSEngine,
  ParentClass: Sendable,
  PropertyNameAccumulator,
  NativeStaticValue,
  NativeStaticFunction
>: @unchecked Sendable {
  package let definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
  package let usesManagedParent: Bool
  package var staticValueNames: [ContiguousArray<CChar>] = []
  package var staticValues: [NativeStaticValue] = []
  package var staticFunctionNames: [ContiguousArray<CChar>] = []
  package var staticFunctions: [NativeStaticFunction] = []

  package init(
    definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    usesManagedParent: Bool
  ) {
    self.definition = definition
    self.usesManagedParent = usesManagedParent
  }

  package convenience init(
    definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    resolvingManagedParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) {
    self.init(
      definition: definition,
      usesManagedParent: definition.parentClass.flatMap { resolvingManagedParentDefinition($0) }
        != nil
    )
  }

  package convenience init(
    definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    lookup: JSEngineClassDefinitionLookup<E, ParentClass, PropertyNameAccumulator>
  ) {
    self.init(
      definition: definition,
      usesManagedParent: definition.parentClass.flatMap {
        lookup.resolveParentDefinition($0)
      } != nil
    )
  }
}

package final class JSClassAutoObjectStorage<
  E: JSEngine,
  ParentClass: Sendable,
  PropertyNameAccumulator
>: @unchecked Sendable {
  package let definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>
  package let instance: AnyObject
  package let finalizeDepth: Int

  package init(
    definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    instance: AnyObject,
    finalizeDepth: Int
  ) {
    self.definition = definition
    self.instance = instance
    self.finalizeDepth = finalizeDepth
  }

  package convenience init(
    definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    instance: AnyObject,
    resolvingParentDefinition:
      (ParentClass) -> JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>?
  ) {
    self.init(
      definition: definition,
      instance: instance,
      finalizeDepth: definition.exportedDefinitionCount(
        resolvingParentDefinition: resolvingParentDefinition
      )
    )
  }

  package convenience init(
    definition: JSEngineClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    instance: AnyObject,
    lookup: JSEngineClassDefinitionLookup<E, ParentClass, PropertyNameAccumulator>
  ) {
    self.init(
      definition: definition,
      instance: instance,
      finalizeDepth: lookup.exportedDefinitionCount(of: definition)
    )
  }

  package func typedInstance<T: AnyObject>(as type: T.Type) -> T? {
    instance as? T
  }
}
