import JavaScriptCore
import SwiftJavaScript

package struct JSCContextHandle: JSContextManualReferenceCountedHandle, Equatable,
  @unchecked Sendable
{
  package let ref: JSGlobalContextRef
  package let ownsContext: Bool
  package let globalObjectClass: JSClassRef?
  /// The surface callback entry's function class: its `callAsFunction`
  /// trampoline boxes `JSFunctionCallback<JSCEngine>`.
  package let surfaceFunctionClass: JSClassRef?
  package let propertyNamesFunction: JSObjectRef?

  package init(runtime: JSCRuntimeHandle) {
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
    self.surfaceFunctionClass = makeJavaScriptCoreSurfaceFunctionClass()
    self.propertyNamesFunction = propertyNamesFunction
  }

  package init(borrowing ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = false
    self.globalObjectClass = nil
    self.surfaceFunctionClass = nil
    self.propertyNamesFunction = nil
  }

  package init(adopting ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = true
    self.globalObjectClass = nil
    self.surfaceFunctionClass = nil
    self.propertyNamesFunction = nil
  }

  package var globalObjectRef: JSObjectRef {
    JSContextGetGlobalObject(ref)
  }

  package var surfaceFunctionClassRef: JSClassRef {
    if let surfaceFunctionClass {
      return surfaceFunctionClass
    }
    guard let ownerSurfaceFunctionClass = ownerDriverContextHandle?.surfaceFunctionClass else {
      preconditionFailure(
        "JSCContextHandle could not resolve the surface function class for a borrowing context"
      )
    }
    return ownerSurfaceFunctionClass
  }

  package var propertyNamesFunctionRef: JSObjectRef? {
    if let propertyNamesFunction {
      return propertyNamesFunction
    }
    return ownerDriverContextHandle?.propertyNamesFunction
  }

  /// The driver handle of the context that installed this borrowing handle's
  /// data box. A borrowing handle is built inside an engine callback from the
  /// raw context, so the class refs and the property-names helper live on the
  /// owning context's handle.
  private var ownerDriverContextHandle: JSCContextHandle? {
    JSCContext.borrow(ctx: ref)?.driverContextHandle
  }

  package var engineType: JSCEngine.Type {
    JSCEngine.self
  }

  @discardableResult
  package func retainReference() -> Bool {
    guard ownsContext else {
      return false
    }
    if let globalObjectClass {
      JSClassRetain(globalObjectClass)
    }
    if let surfaceFunctionClass {
      JSClassRetain(surfaceFunctionClass)
    }
    if let propertyNamesFunction {
      JSValueProtect(ref, propertyNamesFunction)
    }
    JSGlobalContextRetain(ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    guard ownsContext else {
      return false
    }
    if let surfaceFunctionClass {
      JSClassRelease(surfaceFunctionClass)
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

private func makeJavaScriptCoreSurfaceFunctionClass() -> JSClassRef {
  var definition = makeJavaScriptCoreSurfaceFunctionClassDefinition()
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

extension JSCContextHandle: Hashable {
  package static func == (lhs: JSCContextHandle, rhs: JSCContextHandle)
    -> Bool
  {
    lhs.ref == rhs.ref
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(ref)
  }
}
