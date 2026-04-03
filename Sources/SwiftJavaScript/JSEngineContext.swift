public actor JSEngineContext<E: JSEngine> {
  nonisolated package let driverContextHandle: E.ContextHandle
  public let virtualMachine: JSEngineVirtualMachine<E>
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  package init(
    virtualMachine: JSEngineVirtualMachine<E>,
    driverContextHandle: E.ContextHandle
  ) {
    self.virtualMachine = virtualMachine
    self.unownedExecutor = virtualMachine.unownedExecutor
    self.driverContextHandle = driverContextHandle
  }

  deinit {
    _ = driverContextHandle.releaseReference()
  }
}

extension JSEngineContext: Equatable where E.ContextHandle: Equatable {
  nonisolated public static func == (lhs: JSEngineContext<E>, rhs: JSEngineContext<E>) -> Bool {
    lhs.driverContextHandle == rhs.driverContextHandle
  }
}

extension JSEngineContext: Hashable where E.ContextHandle: Hashable {
  nonisolated public func hash(into hasher: inout Hasher) {
    hasher.combine(driverContextHandle)
  }
}
