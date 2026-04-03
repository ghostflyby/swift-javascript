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

extension JSEngineContext {
  public func withInstantContext<R: ~Copyable, Failure: Error>(
    _ body: (borrowing JSEngineInstantContext<E>) throws(Failure) -> R
  ) throws(Failure) -> R {
    let instantContext = JSEngineInstantContext<E>(handle: driverContextHandle)
    return try body(instantContext)
  }

  public func makeString(_ value: String) -> JSEngineValue<E> {
    withInstantContext { instantContext in
      instantContext.makeString(value)
    }
  }

  public func makeNumber(_ value: Double) -> JSEngineValue<E> {
    withInstantContext { instantContext in
      instantContext.makeNumber(value)
    }
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSEngineValue<E> {
    withInstantContext { instantContext in
      instantContext.makeNumber(value)
    }
  }

  public func makeBoolean(_ value: Bool) -> JSEngineValue<E> {
    withInstantContext { instantContext in
      instantContext.makeBoolean(value)
    }
  }

  public func makeNull() -> JSEngineValue<E> {
    withInstantContext { instantContext in
      instantContext.makeNull()
    }
  }

  public func makeUndefined() -> JSEngineValue<E> {
    withInstantContext { instantContext in
      instantContext.makeUndefined()
    }
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
