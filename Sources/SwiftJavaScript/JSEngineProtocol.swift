public protocol JSEngine: Sendable, _JSEngineRuntimeDriver, _JSEnginePropertyDriver,
  _JSEngineInvocationDriver, _JSEngineTypedArrayDriver, _JSEngineStringDriver
{}
