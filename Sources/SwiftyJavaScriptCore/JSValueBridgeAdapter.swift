import JavaScriptCore

extension SwiftJavaScript.JSInstantContext where E == JavaScriptCoreEngine {
  func looselyEquals(
    _ lhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    _ rhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JSValueIsEqual(globalContextRef, lhs.ref, rhs.ref, nil)
  }

  func strictlyEquals(
    _ lhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    _ rhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JSValueIsStrictEqual(globalContextRef, lhs.ref, rhs.ref)
  }
}
