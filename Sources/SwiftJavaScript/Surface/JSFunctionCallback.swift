/// The signature for a JavaScript-to-Swift function callback, expressed on the
/// engine surface.
///
/// `this` is an Escapable call-argument token so the stored closure type stays
/// `@Sendable`/escapable; call `context.value(from:)` to borrow it as a local
/// `C.Value`. The arguments view lends values inside its own `withValue`
/// closure. The result is the scope's callback-exit carrier
/// (`C.CallbackReturn`).
///
/// - Parameters:
///   - context: The callback window's synchronous scope.
///   - this:    The `this` value token for the function call (callback-scoped).
///   - arguments: The function call arguments (callback-scoped).
/// - Returns: The scope's callback-exit handoff (temporary, persistent, or
///   exception).
public typealias JSFunctionCallback<C: JSInstantContext & ~Copyable> =
  @Sendable (
    _ context: borrowing C,
    _ this: C.Context.CallArgument,
    _ arguments: borrowing C.CallbackArguments
  ) -> C.CallbackReturn
