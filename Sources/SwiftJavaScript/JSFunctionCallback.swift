public typealias JSFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSInstantContext<E>,
    _ this: borrowing JSValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> JSResult<JSValue<E>>

public struct JSRetainedFunctionCallbackResult<E: JSEngine>: ~Copyable {
  public let isException: Bool
  public let handle: JSValueHandle<E>

  public init(value handle: JSValueHandle<E>) {
    self.isException = false
    self.handle = handle
  }

  public init(exception handle: JSValueHandle<E>) {
    self.isException = true
    self.handle = handle
  }
}

public typealias JSRetainedFunctionCallback<E: JSEngine> =
  (
    _ context: borrowing JSInstantContext<E>,
    _ this: borrowing JSValue<E>,
    _ arguments: borrowing JSArguments<E>
  ) -> JSRetainedFunctionCallbackResult<E>

package func retainedFunctionCallback<E: JSEngine>(
  _ callback: @escaping JSFunctionCallback<E>
) -> JSRetainedFunctionCallback<E> {
  { context, this, arguments in
    let result = retainResult(callback(context, this, arguments))
    switch consume result {
    case .value(let value):
      return JSRetainedFunctionCallbackResult(value: value.takeHandle())
    case .exception(let exception):
      return JSRetainedFunctionCallbackResult(exception: exception.takeHandle())
    }
  }
}
