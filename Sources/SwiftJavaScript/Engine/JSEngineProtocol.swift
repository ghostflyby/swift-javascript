/// Driver face required by `JSContext`: context/runtime value operations,
/// property access, and prepared-script evaluation. Invocation and
/// typed-array operations live on `JSValue` extensions with their own
/// driver constraints, so `JSContext` does not demand those capabilities.
public typealias JSContextEngine = JSEnginePropertyDriver & JSEnginePreparedScriptDriver

public typealias JSEngine = Sendable & JSContextEngine
  & JSEngineInvocationDriver & JSEngineTypedArrayDriver
