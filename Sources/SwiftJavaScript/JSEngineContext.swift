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

  public func makeString(_ value: String) -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeString(value)
    }
  }

  public func makeNumber(_ value: Double) -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeNumber(value)
    }
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeNumber(value)
    }
  }

  public func makeBoolean(_ value: Bool) -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeBoolean(value)
    }
  }

  public func makeNull() -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeNull()
    }
  }

  public func makeUndefined() -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeUndefined()
    }
  }

  public func withGlobalObject<R: ~Copyable>(
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    withInstantContext { instantContext in
      instantContext.withGlobalObject(body)
    }
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, with: attributes)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    withInstantContext { instantContext in
      instantContext.setGlobalProperty(value, forKey: key, using: converter, with: attributes)
    }
  }

  public func getGlobalProperty(forKey key: String) -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.getGlobalProperty(forKey: key)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type
  ) -> C.SwiftType {
    withInstantContext { instantContext in
      instantContext.getGlobalProperty(forKey: key, using: converter)
    }
  }

  public func deleteGlobalProperty(forKey key: String) {
    withInstantContext { instantContext in
      instantContext.deleteGlobalProperty(forKey: key)
    }
  }

  public func hasGlobalProperty(_ key: String) -> Bool {
    withInstantContext { instantContext in
      instantContext.hasGlobalProperty(key)
    }
  }

  public func makeObject() -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeObject()
    }
  }

  public func makeArray() -> JSValue<E> {
    withInstantContext { instantContext in
      instantContext.makeArray()
    }
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSEngineFunctionCallback<E>
  ) -> JSValue<E> where E.Engine == E {
    withInstantContext { instantContext in
      instantContext.makeFunction(named: name, callback: callback)
    }
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSEngineFunctionCallback<E>
  ) where E.Engine == E {
    withInstantContext { instantContext in
      instantContext.installGlobalFunction(named: name, with: attributes, callback: callback)
    }
  }

  public func evaluateScript(_ script: String) -> JSResult<JSValue<E>> {
    withInstantContext { instantContext in
      instantContext.evaluateScript(script)
    }
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where Script: JSString, Script: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(script, startingLineNumber: startingLineNumber)
    }
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where Script: JSString, Script: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    }
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> where SourceURL: JSString, SourceURL: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    }
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>> {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    }
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValue<E>>
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    withInstantContext { instantContext in
      instantContext.evaluateScript(
        script,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
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
