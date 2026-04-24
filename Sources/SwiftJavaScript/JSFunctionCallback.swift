public typealias JSFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSInstantContext<E>,
    _ this: borrowing JSValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> JSResult<JSValue<E>>

package typealias JSRetainedFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSInstantContext<E>,
    _ this: borrowing JSValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> (isException: Bool, handle: JSValueHandle<E>)

package func retainedFunctionCallback<E: JSEngine>(
  _ callback: @escaping JSFunctionCallback<E>
) -> JSRetainedFunctionCallback<E> {
  { context, this, arguments in
    let result = retainResult(callback(context, this, arguments))
    switch consume result {
    case .value(let value):
      return (false, value.takeHandle())
    case .exception(let exception):
      return (true, exception.takeHandle())
    }
  }
}
