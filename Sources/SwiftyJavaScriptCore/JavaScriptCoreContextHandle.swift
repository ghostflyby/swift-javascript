import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreContextHandle: JSContextManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSGlobalContextRef
  package let ownsContext: Bool
  package let globalObjectClass: JSClassRef?
  package let functionClass: JSClassRef?

  package init(runtime: JavaScriptCoreRuntimeHandle) {
    var definition = kJSClassDefinitionEmpty
    let globalObjectClass = JSClassCreate(&definition)
    self.ref = JSGlobalContextCreateInGroup(runtime.ref, globalObjectClass)
    self.ownsContext = true
    self.globalObjectClass = globalObjectClass
    self.functionClass = makeJavaScriptCoreFunctionClass()
  }

  package init(borrowing ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = false
    self.globalObjectClass = nil
    self.functionClass = nil
  }

  package init(adopting ref: JSGlobalContextRef) {
    self.ref = ref
    self.ownsContext = true
    self.globalObjectClass = nil
    self.functionClass = nil
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

  public func bindContextOwner(_ owner: AnyObject) {
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
    JSGlobalContextRelease(ref)
    return true
  }
}

private func makeJavaScriptCoreFunctionClass() -> JSClassRef {
  var definition = makeJavaScriptCoreFunctionClassDefinition()
  return JSClassCreate(&definition)!
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
