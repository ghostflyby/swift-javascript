import JavaScriptCore

extension SwiftJavaScript.JSInstantContext where E == JavaScriptCoreEngine {
  func looselyEquals(
    _ lhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    _ rhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JSValueIsEqual(driverContextHandle.ref, lhs.ref, rhs.ref, nil)
  }

  func strictlyEquals(
    _ lhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    _ rhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JSValueIsStrictEqual(driverContextHandle.ref, lhs.ref, rhs.ref)
  }
}
