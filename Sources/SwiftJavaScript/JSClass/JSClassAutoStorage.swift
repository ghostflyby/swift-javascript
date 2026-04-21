package final class JSClassAutoNativeClassBacking<
  Definition: JSClassDefinition,
  NativeStaticValue,
  NativeStaticFunction
>: @unchecked Sendable {
  package let definition: Definition
  package let usesManagedParent: Bool
  package var staticValueNames: [ContiguousArray<CChar>] = []
  package var staticValues: [NativeStaticValue] = []
  package var staticFunctionNames: [ContiguousArray<CChar>] = []
  package var staticFunctions: [NativeStaticFunction] = []

  package init(
    definition: Definition,
    usesManagedParent: Bool
  ) {
    self.definition = definition
    self.usesManagedParent = usesManagedParent
  }

  package convenience init(
    definition: Definition,
    resolvingManagedParentDefinition:
      (Definition.ParentClass) -> Definition?
  ) {
    self.init(
      definition: definition,
      usesManagedParent: definition.parentClass.flatMap { resolvingManagedParentDefinition($0) }
        != nil
    )
  }

  package convenience init(
    definition: Definition,
    lookup: JSClassDefinitionLookup<Definition>
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
  Definition: JSClassDefinition
>: @unchecked Sendable {
  package let definition: Definition
  package let instance: AnyObject
  package let finalizeDepth: Int

  package init(
    definition: Definition,
    instance: AnyObject,
    finalizeDepth: Int
  ) {
    self.definition = definition
    self.instance = instance
    self.finalizeDepth = finalizeDepth
  }

  package convenience init(
    definition: Definition,
    instance: AnyObject,
    resolvingParentDefinition:
      (Definition.ParentClass) -> Definition?
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
    definition: Definition,
    instance: AnyObject,
    lookup: JSClassDefinitionLookup<Definition>
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
