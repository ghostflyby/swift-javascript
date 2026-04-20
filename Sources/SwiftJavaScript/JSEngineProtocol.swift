public protocol JSEngine: Sendable, SendableMetatype, _JSEngineRuntimeDriver,
  _JSEnginePropertyDriver,
  _JSEngineInvocationDriver, _JSEngineTypedArrayDriver, _JSEngineStringDriver
{}
