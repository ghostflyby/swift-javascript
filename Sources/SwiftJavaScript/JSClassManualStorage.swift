package final class JSClassManualNativeClassBacking<NativeStaticValue, NativeStaticFunction>:
  @unchecked Sendable
{
  package var className: ContiguousArray<CChar>? = nil
  package var staticValueNames: [ContiguousArray<CChar>] = []
  package var staticValues: [NativeStaticValue] = []
  package var staticFunctionNames: [ContiguousArray<CChar>] = []
  package var staticFunctions: [NativeStaticFunction] = []

  package init() {}
}
