public protocol JSEngine: Sendable, _JSEngineRuntimeDriver, _JSEnginePropertyDriver,
  _JSEngineInvocationDriver
{
  associatedtype ValueHandle: JSValueManualReferenceCountedHandle
}
