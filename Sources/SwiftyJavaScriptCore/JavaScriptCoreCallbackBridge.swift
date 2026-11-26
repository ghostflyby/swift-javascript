import JavaScriptCore
import SwiftJavaScript

// MARK: - Surface callback trampoline (S6)
//
// The surface entry boxes `JSFunctionCallback<JSCInstantContext>` and uses its own
// function class. The trampoline reads only `isException` and the borrowed
// handle of the returned carrier; JSC is GC-managed, so the returned ref needs
// no reference accounting and the owning arena keeps its explicit root until
// its own drain unprotects it.

private let javaScriptCoreSurfaceFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let scope = JSCInstantContext(contextRef: ctx)

  let callback = Unmanaged<Box<JSFunctionCallback<JSCInstantContext>>>.fromOpaque(
    JSObjectGetPrivate(function)!
  ).takeUnretainedValue().value

  let thisValue = JSCValue(ref: thisObject, contextRef: ctx)

  let result = withJavaScriptCoreSurfaceCallbackArguments(
    pointer: arguments,
    count: Int(argumentCount),
  ) { args in
    callback(scope, thisValue, args)
  }

  if result.isException {
    exception?.pointee = result.ref
    return JSValueMakeUndefined(ctx)
  }
  return result.ref
}

func makeJavaScriptCoreSurfaceFunctionClassDefinition() -> JavaScriptCore.JSClassDefinition {
  var definition = JavaScriptCore.kJSClassDefinitionEmpty
  definition.callAsFunction = javaScriptCoreSurfaceFunctionCallback
  definition.finalize = { function in
    guard let function, let privateData = JSObjectGetPrivate(function) else {
      return
    }
    let callback = Unmanaged<Box<JSFunctionCallback<JSCInstantContext>>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

/// The call frame's borrowed refs are exposed as the engine's
/// `JSCCallbackArguments`.
func withJavaScriptCoreSurfaceCallbackArguments<R: ~Copyable>(
  pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSCCallbackArguments) -> R
) -> R {
  var ref: JSValueRef? = nil
  return withUnsafePointer(
    to: &ref,
    { empty in
      let arguments = JSCCallbackArguments(
        count: count,
        borrowedValueRefAt: { index in
          guard
            index >= 0,
            index < count,
            let valueRef = (pointer ?? empty)[index]
          else {
            return nil
          }
          return valueRef
        }
      )
      return body(arguments)
    })
}

/// Class-callback counterpart of `withJavaScriptCoreSurfaceCallbackArguments`:
/// the call frame's borrowed refs are exposed as the surface `JSCArguments`,
/// the argument view the class definition closures consume (S11).
func withJavaScriptCoreArguments<R: ~Copyable>(
  _ pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSCArguments) -> R
) -> R {
  var ref: JSValueRef? = nil
  return withUnsafePointer(
    to: &ref,
    { empty in
      let arguments = JSCArguments(
        count: count,
        borrowedValueRefAt: { index, _ in
          guard
            index >= 0,
            index < count,
            let valueRef = (pointer ?? empty)[index]
          else {
            return nil
          }
          return valueRef
        }
      )
      return body(arguments)
    })
}
