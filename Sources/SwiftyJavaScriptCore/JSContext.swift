@preconcurrency import JavaScriptCore

extension SwiftJavaScript.JSContext where E == JavaScriptCoreEngine {
  nonisolated var globalContextRef: JSGlobalContextRef {
    driverContextHandle.ref
  }
}
