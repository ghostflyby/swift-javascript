package final class JSClassAutoNativeClassBacking<
  E: JSEngine,
  ParentClass: Sendable,
  PropertyNameAccumulator,
  NativeStaticValue,
  NativeStaticFunction
>: @unchecked Sendable {
  package let definition: JSClassDefinition<E, ParentClass, PropertyNameAccumulator>
  package let usesManagedParent: Bool
  package var staticValueNames: [ContiguousArray<CChar>] = []
  package var staticValues: [NativeStaticValue] = []
  package var staticFunctionNames: [ContiguousArray<CChar>] = []
  package var staticFunctions: [NativeStaticFunction] = []

  package init(
    definition: JSClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    usesManagedParent: Bool
  ) {
    self.definition = definition
    self.usesManagedParent = usesManagedParent
  }
}

package final class JSClassAutoObjectStorage<
  E: JSEngine,
  ParentClass: Sendable,
  PropertyNameAccumulator
>: @unchecked Sendable {
  package let definition: JSClassDefinition<E, ParentClass, PropertyNameAccumulator>
  package let instance: AnyObject
  package let finalizeDepth: Int

  package init(
    definition: JSClassDefinition<E, ParentClass, PropertyNameAccumulator>,
    instance: AnyObject,
    finalizeDepth: Int
  ) {
    self.definition = definition
    self.instance = instance
    self.finalizeDepth = finalizeDepth
  }
}
