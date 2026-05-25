/// The signature for a JavaScript-to-Swift function callback.
///
/// - Parameters:
///   - context: The callback context providing value creation and scope operations.
///   - this:    The `this` value for the function call (temporary).
///   - arguments: The function call arguments (temporary).
/// - Returns: A `JSCallbackReturn` containing either a temporary or persistent value.
public typealias JSFunctionCallback<E: JSEngine> = (
  _ context: borrowing JSInstantContext<E>,
  _ this: borrowing JSCallbackValue<E>,
  _ arguments: borrowing JSCallbackArguments<E>
) -> JSCallbackReturn<E>
