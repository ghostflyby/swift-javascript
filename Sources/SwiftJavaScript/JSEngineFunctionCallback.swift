public typealias JSEngineFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSEngineInstantContext<E>,
    _ function: borrowing JSValue<E>,
    _ this: borrowing JSValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> JSResult<JSValue<E>>
