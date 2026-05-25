import JavaScriptCore
import SwiftJavaScript

private let javaScriptCoreFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let contextHandle = JavaScriptCoreContextHandle(borrowing: ctx)
  let scope = JSCallbackScope<JavaScriptCoreEngine>(contextHandle: contextHandle)

  let callback = Unmanaged<Box<JSFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(
    JSObjectGetPrivate(function)!
  ).takeUnretainedValue().value

  let thisValue = JSCallbackValue<JavaScriptCoreEngine>(
    handle: JavaScriptCoreValueHandle(ref: thisObject),
  )

  let result = withJavaScriptCoreCallbackArguments(
    pointer: arguments,
    count: Int(argumentCount),
    contextRef: ctx,
  ) { args in
    callback(scope.context, thisValue, args)
  }

  if result.isException {
    exception?.pointee = result.handle.ref
    return JSValueMakeUndefined(ctx)
  }
  return result.handle.ref
}

func makeJavaScriptCoreFunctionClassDefinition() -> JavaScriptCore.JSClassDefinition {
  var definition = JavaScriptCore.kJSClassDefinitionEmpty
  definition.callAsFunction = javaScriptCoreFunctionCallback
  definition.finalize = { function in
    guard let function, let privateData = JSObjectGetPrivate(function) else {
      return
    }
    let callback = Unmanaged<Box<JSFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

func withJavaScriptCoreCallbackArguments<R: ~Copyable>(
  pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  contextRef: JSGlobalContextRef,
  _ body: (borrowing JSCallbackArguments<JavaScriptCoreEngine>) -> R
) -> R {
  var ref: JSValueRef? = nil
  return withUnsafePointer(
    to: &ref,
    { empty in
      let arguments = JSCallbackArguments<JavaScriptCoreEngine>(
        count: count,
        borrowedValueHandleAt: { index in
          guard
            index >= 0,
            index < count,
            let valueRef = (pointer ?? empty)[index]
          else {
            return nil
          }
          return JavaScriptCoreValueHandle(ref: valueRef)
        }
      )
      return body(arguments)
    })
}

// Legacy version for JSClass callbacks (uses old JSArguments pattern)
func withJavaScriptCoreArguments<R: ~Copyable>(
  _ pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSArguments<JavaScriptCoreEngine>) -> R
) -> R {
  var ref: JSValueRef? = nil
  return withUnsafePointer(
    to: &ref,
    { empty in
      let arguments = JSArguments<JavaScriptCoreEngine>(
        count: count,
        borrowedValueHandleAt: { index, contextHandle in
          guard
            index >= 0,
            index < count,
            let valueRef = (pointer ?? empty)[index]
          else {
            return nil
          }
          return JavaScriptCoreValueHandle(ref: valueRef)
        }
      )
      return body(arguments)
    })
}
