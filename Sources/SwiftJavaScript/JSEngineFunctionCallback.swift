public typealias JSEngineFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSEngineInstantContext<E>,
    _ function: borrowing JSEngineValue<E>,
    _ this: borrowing JSEngineValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> JSResult<JSEngineValue<E>>