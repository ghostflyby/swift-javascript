public typealias JSFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSInstantContext<E>,
    _ this: borrowing JSValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> JSResult<JSValue<E>>
