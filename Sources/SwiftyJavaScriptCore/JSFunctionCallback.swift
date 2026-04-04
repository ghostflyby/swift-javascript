public typealias JSFunctionCallback =
  (
    _ context: borrowing JSInstantContext,
    _ function: borrowing JSValue,
    _ this: borrowing JSValue,
    _ arguments: borrowing JSArguments<JavaScriptCoreEngine>
  ) -> JSResult
