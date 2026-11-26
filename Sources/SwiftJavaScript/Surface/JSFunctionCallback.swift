/// The signature for a JavaScript-to-Swift function callback, expressed on the
/// engine surface.
///
/// The parameters are the scope's own views (`C.Value`, `C.CallbackArguments`)
/// and the result is the scope's callback-exit carrier (`C.CallbackReturn`). `@Sendable` keeps the closure
/// storable on
/// the engine side: it is invoked from the engine's callback window, so it
/// must not carry non-`Sendable` captured state into that call.
///
/// - Parameters:
///   - context: The callback window's synchronous scope.
///   - this:    The `this` value for the function call (callback-scoped).
///   - arguments: The function call arguments (callback-scoped).
/// - Returns: The scope's callback-exit handoff (temporary, persistent, or
///   exception).
public typealias JSFunctionCallback<C: JSInstantContext & ~Copyable> =
  @Sendable (
    _ context: borrowing C,
    _ this: borrowing C.Value,
    _ arguments: borrowing C.CallbackArguments
  ) -> C.CallbackReturn
