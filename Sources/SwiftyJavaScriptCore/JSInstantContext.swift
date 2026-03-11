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

  public func withGlobalObject<R: ~Copyable>(_ body: (borrowing JSValue) -> R) -> R {
    let globalObject = JSValue(ref: globalObjectRef, ctx: self)
    return body(globalObject)
  }

  public func makeString(_ value: String) -> JSValue {
    JSValue(string: value, in: self)
  }

  public func makeNumber(_ value: Double) -> JSValue {
    JSValue(number: value, in: self)
  }

  public func makeNumber(_ value: some BinaryInteger) -> JSValue {
    JSValue(number: value, in: self)
  }

  public func makeBoolean(_ value: Bool) -> JSValue {
    JSValue(boolean: value, in: self)
  }

  public func makeNull() -> JSValue {
    JSValue(nullIn: self)
  }

  public func makeUndefined() -> JSValue {
    JSValue(undefinedIn: self)
  }

  public func makeObject() -> JSValue {
    JSValue(objectIn: self)
  }

  public func makeArray() -> JSValue {
    JSValue(arrayIn: self)
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSValue.JSFunctionCallback
  ) -> JSValue {
    JSValue(name: name, callback: callback, in: self)
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSValue.JSFunctionCallback
  ) {
    let function = makeFunction(named: name, callback: callback)
    setGlobalProperty(function, forKey: name, with: attributes)
  }

  public func setGlobalProperty<Val>(
    _ value: borrowing Val,
    forKey key: String,
    with attributes: JSPropertyAttributes = .none
  ) where Val: JSValueEncodable, Val: ~Copyable {
    let ownedKey = JSStringManaged(key)
    withGlobalObject { globalObject in
      globalObject.setProperty(value, forKey: ownedKey, with: attributes, in: self)
    }
  }

  public func setGlobalProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: String,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none
  ) {
    let ownedKey = JSStringManaged(key)
    withGlobalObject { globalObject in
      globalObject.setProperty(
        value, forKey: ownedKey, using: converter, with: attributes, in: self)
    }
  }

  public func getGlobalProperty(forKey key: String) -> JSValue {
    let ownedKey = JSStringManaged(key)
    return withGlobalObject { globalObject in
      globalObject.getProperty(forKey: ownedKey, in: self)
    }
  }

  public func getGlobalProperty<C: JSValueDecoder>(
    forKey key: String,
    using converter: C.Type
  ) -> C.SwiftType {
    let ownedKey = JSStringManaged(key)
    return withGlobalObject { globalObject in
      globalObject.getProperty(forKey: ownedKey, using: converter, in: self)
    }
  }

  public func deleteGlobalProperty(forKey key: String) {
    let ownedKey = JSStringManaged(key)
    withGlobalObject { globalObject in
      globalObject.deleteProperty(forKey: ownedKey, in: self)
    }
  }

  public func hasGlobalProperty(_ key: String) -> Bool {
    let ownedKey = JSStringManaged(key)
    return withGlobalObject { globalObject in
      globalObject.hasProperty(ownedKey, in: self)
    }
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
