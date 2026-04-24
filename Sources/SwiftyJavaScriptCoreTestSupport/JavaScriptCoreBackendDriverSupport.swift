import JavaScriptCore
import SwiftyJavaScriptCore

package func makeBackendString(
  _ value: String,
  in context: JavaScriptCoreContextHandle
) -> JSValueHandle<JavaScriptCoreEngine> {
  JavaScriptCoreEngine.makeStringValueHandle(value, context)!
}

@_lifetime(immortal)
package func evaluateBackendScript(
  _ script: String,
  in context: JavaScriptCoreContextHandle,
  sourceURL: String? = nil,
  startingLineNumber: Int32 = 1
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  JavaScriptCoreEngine.evaluateScriptResultHandle(
    script,
    context,
    sourceURL: sourceURL,
    startingLineNumber: startingLineNumber
  )!
}

@_lifetime(immortal)
package func makeBackendObject(
  in context: JavaScriptCoreContextHandle
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  JavaScriptCoreEngine.makeObjectResultHandle(context)!
}

@_lifetime(immortal)
package func makeBackendArray(
  in context: JavaScriptCoreContextHandle
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  JavaScriptCoreEngine.makeArrayResultHandle(context)!
}

package func makeBackendProjectedDefinition() -> JSEngineClassDefinition<
  JavaScriptCoreEngine, JSClass, JavaScriptCore.JSPropertyNameAccumulatorRef
> {
  var definition = SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JavaScriptCore.JSPropertyNameAccumulatorRef
  >()
  definition.className = "BackendProjected"
  definition.staticValues = [
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>(
      name: "version",
      attributes: .readOnly,
      getProperty: { context, _ in
        let value = JSValue(number: 1, in: context)
        return .value(JSValue(retaining: value))
      },
      setProperty: { context, _, _ in
        let value = JSValue(undefinedIn: context)
        return .value(JSValue(retaining: value))
      }
    )
  ]
  definition.staticFunctions = [
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>(
      name: "ping",
      attributes: .dontEnum,
      callAsFunction: { context, _, _ in
        let value = JSValue(string: "pong", in: context)
        return .value(JSValue(retaining: value))
      }
    )
  ]
  definition.behavior.getProperty = { contextHandle, _, _ in
    (false, JavaScriptCoreEngine.makeUndefinedValueHandle(contextHandle)!)
  }
  definition.behavior.setProperty = {
    (
      _: borrowing JSInstantContext<JavaScriptCoreEngine>,
      _: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      _: String,
      _: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) -> JSValueHandle<JavaScriptCoreEngine>? in
    nil
  }
  definition.hasProperty = {
    (
      _: borrowing JSInstantContext<JavaScriptCoreEngine>,
      _: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      _: String
    ) -> Bool in
    true
  }
  definition.deleteProperty = {
    (
      _: borrowing JSInstantContext<JavaScriptCoreEngine>,
      _: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      _: String
    ) -> Bool in
    true
  }
  definition.behavior.getPropertyNames = {
    (
      _: borrowing JSInstantContext<JavaScriptCoreEngine>,
      _: inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      _: JavaScriptCore.JSPropertyNameAccumulatorRef
    ) in
  }
  definition.behavior.callAsFunction = { context, _, _, _ in
    JavaScriptCoreEngine.makeUndefinedValueHandle(context.driverContextHandle)!
  }
  definition.behavior.callAsConstructor = { context, _, _, _ in
    switch JavaScriptCoreEngine.makeObjectResultHandle(context.driverContextHandle)! {
    case .value(let handle):
      return handle
    case .exception(let handle):
      return handle
    }
  }
  definition.behavior.hasInstance = {
    (
      _: borrowing JSInstantContext<JavaScriptCoreEngine>,
      _: inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      _: inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) -> Bool in
    false
  }
  definition.behavior.convertToType = { context, _, _, _ in
    JavaScriptCoreEngine.makeUndefinedValueHandle(context.driverContextHandle)!
  }
  return definition
}
