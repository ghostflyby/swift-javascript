import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreContextHandle: JSContextManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSGlobalContextRef
  package let ownsContext: Bool
  package let globalObjectClass: JSClassRef?
  package let functionClass: JSClassRef?
  package let propertyNamesFunction: JSObjectRef?

  package init(runtime: JavaScriptCoreRuntimeHandle) {
    var definition = kJSClassDefinitionEmpty
    let globalObjectClass = JSClassCreate(&definition)
    guard let ref = JSGlobalContextCreateInGroup(runtime.ref, globalObjectClass) else {
      preconditionFailure("JavaScriptCore could not create a global context")
    }
    let propertyNamesFunction = makeJavaScriptCorePropertyNamesFunction(in: ref)
    if let propertyNamesFunction {
      JSValueProtect(ref, propertyNamesFunction)
    }
    self.ref = ref
    self.ownsContext = true
    self.globalObjectClass = globalObjectClass
    self.functionClass = makeJavaScriptCoreFunctionClass()
    self.propertyNamesFunction = propertyNamesFunction
  }

  package init(borrowing ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = false
    self.globalObjectClass = nil
    self.functionClass = nil
    self.propertyNamesFunction = nil
  }

  package init(adopting ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = true
    self.globalObjectClass = nil
    self.functionClass = nil
    self.propertyNamesFunction = nil
  }

  package var globalObjectRef: JSObjectRef {
    JSContextGetGlobalObject(ref)
  }

  package var functionClassRef: JSClassRef {
    if let functionClass {
      return functionClass
    }
    return SwiftJavaScript.JSContext<JavaScriptCoreEngine>.borrow(ctx: ref)
      .driverContextHandle.functionClassRef
  }

  package var propertyNamesFunctionRef: JSObjectRef? {
    if let propertyNamesFunction {
      return propertyNamesFunction
    }
    return SwiftJavaScript.JSContext<JavaScriptCoreEngine>.borrow(ctx: ref)
      .driverContextHandle.propertyNamesFunctionRef
  }

  public func bindContextOwner<E>(_ owner: SwiftJavaScript.JSContext<E>)
  where JavaScriptCoreContextHandle == E.ContextHandle, E: SwiftJavaScript.JSEngine {
    JSObjectSetPrivate(globalObjectRef, Unmanaged.passUnretained(owner).toOpaque())
  }

  public var engineType: JavaScriptCoreEngine.Type {
    JavaScriptCoreEngine.self
  }

  @discardableResult
  public func retainReference() -> Bool {
    guard ownsContext else {
      return false
    }
    if let globalObjectClass {
      JSClassRetain(globalObjectClass)
    }
    if let functionClass {
      JSClassRetain(functionClass)
    }
    if let propertyNamesFunction {
      JSValueProtect(ref, propertyNamesFunction)
    }
    JSGlobalContextRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard ownsContext else {
      return false
    }
    if let functionClass {
      JSClassRelease(functionClass)
    }
    if let globalObjectClass {
      JSClassRelease(globalObjectClass)
    }
    if let propertyNamesFunction {
      JSValueUnprotect(ref, propertyNamesFunction)
    }
    JSGlobalContextRelease(ref)
    return true
  }
}

private func makeJavaScriptCoreFunctionClass() -> JSClassRef {
  var definition = makeJavaScriptCoreFunctionClassDefinition()
  return JSClassCreate(&definition)!
}

private func makeJavaScriptCorePropertyNamesFunction(in context: JSGlobalContextRef)
  -> JSObjectRef?
{
  let source = """
    (function(keys) {
      return function(value) {
        return keys(value);
      };
    })(Object.keys)
    """
  return withJavaScriptCoreString(source) { scriptRef in
    var exception: JSValueRef?
    guard
      let value = JSEvaluateScript(context, scriptRef, nil, nil, 1, &exception),
      exception == nil
    else {
      return nil
    }
    return JSValueToObject(context, value, nil)
  }
}

extension JavaScriptCoreContextHandle: Hashable {
  public static func == (lhs: JavaScriptCoreContextHandle, rhs: JavaScriptCoreContextHandle)
    -> Bool
  {
    lhs.ref == rhs.ref
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ref)
  }
}

extension SwiftJavaScript.JSContext where E == JavaScriptCoreEngine {
  nonisolated internal var javaScriptCoreContextRef: JSGlobalContextRef {
    driverContextHandle.ref
  }
}
