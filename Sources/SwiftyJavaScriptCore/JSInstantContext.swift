import JavaScriptCore

public struct JSInstantContext: ~Copyable {
  public let globalContextRef: JSGlobalContextRef

  init(ctx: JSContextRef) {
    self.globalContextRef = ctx
  }
}

extension JSInstantContext {
  var globalObjectRef: JSObjectRef {
    JSContextGetGlobalObject(globalContextRef)!
  }

  var actorContext: JSContext {
    JSContext.borrow(ctx: globalContextRef)
  }

  public func withGlobalObject<R>(_ body: (borrowing JSValue) -> R) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(globalObject)
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSValue.JSFunctionCallback
  ) -> JSValue {
    JSValue(name: name, callback: callback, in: self)
  }

  public func evaluateScript(_ script: String) -> JSResult {
    let scriptString = JSStringValue(script)
    return evaluateScript(scriptString, startingLineNumber: 1)
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    evaluateScript(scriptRef: script.ref, sourceURLRef: nil, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<Script>(
    _ script: borrowing Script,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult where Script: JSString, Script: ~Copyable {
    let sourceURLString = JSStringValue(sourceURL)
    return evaluateScript(
      script, sourceURL: sourceURLString, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<SourceURL>(
    _ script: String,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult where SourceURL: JSString, SourceURL: ~Copyable {
    let scriptString = JSStringValue(script)
    return evaluateScript(
      scriptString, sourceURL: sourceURL, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript(
    _ script: String,
    sourceURL: String,
    startingLineNumber: Int32 = 1
  ) -> JSResult {
    let scriptString = JSStringValue(script)
    let sourceURLString = JSStringValue(sourceURL)
    return evaluateScript(
      scriptString, sourceURL: sourceURLString, startingLineNumber: startingLineNumber)
  }

  public func evaluateScript<Script, SourceURL>(
    _ script: borrowing Script,
    sourceURL: borrowing SourceURL,
    startingLineNumber: Int32 = 1
  ) -> JSResult
  where Script: JSString, Script: ~Copyable, SourceURL: JSString, SourceURL: ~Copyable {
    evaluateScript(
      scriptRef: script.ref, sourceURLRef: sourceURL.ref, startingLineNumber: startingLineNumber)
  }

  private func evaluateScript(
    scriptRef: JSStringRef,
    sourceURLRef: JSStringRef?,
    startingLineNumber: Int32
  ) -> JSResult {
    var exception: JSValueRef?
    let result = JSEvaluateScript(
      globalContextRef,
      scriptRef,
      nil,
      sourceURLRef,
      startingLineNumber,
      &exception
    )

    if let exception {
      return .exception(JSValue(ref: exception, ctx: self))
    }

    if let result {
      return .value(JSValue(ref: result, ctx: self))
    }

    return .value(JSValue(undefinedIn: self))
  }
}
