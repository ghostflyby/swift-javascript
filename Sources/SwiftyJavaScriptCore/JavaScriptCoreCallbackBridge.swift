import JavaScriptCore
import SwiftJavaScript

private let javaScriptCoreFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSInstantContext<JavaScriptCoreEngine>(ctx: ctx)
  let callback = Unmanaged<Box<JSRetainedFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(
    JSObjectGetPrivate(function)!
  ).takeUnretainedValue().value
  let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObject, ctx: context)
  let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
  let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
  let result = withJavaScriptCoreArguments(argumentsPointer, count: Int(argumentCount)) { args in
    callback(context, thisValue, args)
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
    let callback =
      Unmanaged<Box<JSRetainedFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

func withJavaScriptCoreArguments<R: ~Copyable>(
  _ pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSArguments<JavaScriptCoreEngine>) -> R
) -> R {
  let arguments = JSArguments<JavaScriptCoreEngine>(
    count: count,
    borrowedValueHandleAt: { index, contextHandle in
      guard
        index >= 0,
        index < count,
        let valueRef = pointer?[index]
      else {
        return nil
      }
      return JavaScriptCoreValueHandle(ref: valueRef, contextRef: contextHandle.ref)
    }
  )
  return body(arguments)
}
