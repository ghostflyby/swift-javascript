extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  public func looselyEquals(
    _ other: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      looselyEquals(other, in: callbackContext)
    }
  }

  public func looselyEquals(
    _ other: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext
  )
    -> Bool
  {
    context.looselyEquals(self, other)
  }

  public func strictlyEquals(
    _ other: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    context.withInstantContext { callbackContext in
      strictlyEquals(other, in: callbackContext)
    }
  }

  public func strictlyEquals(
    _ other: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext
  )
    -> Bool
  {
    context.strictlyEquals(self, other)
  }
}
