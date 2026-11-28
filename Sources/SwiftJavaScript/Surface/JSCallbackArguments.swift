/// Borrowed JavaScript callback arguments, viewed as callback-scoped values.
///
/// The element view type is the engine's `Value`; the concrete argument type
/// decides how the engine exposes the call frame's borrowed handles.
public protocol JSCallbackArguments: ~Copyable {
  /// The context this argument view belongs to.
  associatedtype Context: JSContext
  associatedtype Value: JSValue & ~Copyable & ~Escapable
  where Value == Context.Value
  /// The callback window whose argument frame backs these values.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

  var count: Int { get }

  /// Access the callback-scoped argument at `index`. `context` is the
  /// synchronous callback window whose arena (or the engine's argument frame)
  /// backs the borrowed handles. Callback-window-only: `noasync`.
  @available(*, noasync)
  func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing InstantContext,
    _ body: (borrowing Value) -> R
  ) -> R

  /// Throwing counterpart of `withValue`; conversion failures surface as
  /// `JSValueConversionError`. Callback-window-only: `noasync`.
  @available(*, noasync)
  func withThrowingValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing InstantContext,
    _ body: (borrowing Value) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R
}
