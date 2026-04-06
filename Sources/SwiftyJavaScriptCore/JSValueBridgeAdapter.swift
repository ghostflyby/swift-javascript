extension SwiftJavaScript.JSInstantContext where E == JavaScriptCoreEngine {
  func looselyEquals(
    _ lhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    _ rhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JavaScriptCoreEngine.valueEquals(lhs.ref, rhs.ref, in: globalContextRef)
  }

  func strictlyEquals(
    _ lhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    _ rhs: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JavaScriptCoreEngine.valueStrictEquals(lhs.ref, rhs.ref, in: globalContextRef)
  }
}
