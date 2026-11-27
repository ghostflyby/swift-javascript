import JavaScriptCore
import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Each operation drives the `JavaScriptCore` raw-ref statics directly and adopts
// every engine-returned ref onto the passed scope's arena exactly once — the
// exception path included — so the scope drain settles each reference once.
// The `#isolation` forms below adopt onto the context default scope instead;
// both live here because the value type is the engine's.

extension JSCValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreGetStaticStringPropertyHandle(key, on: ref, in: context.contextRef),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    let contextRef = context.contextRef
    return bridgeJSCValueResult(
      javaScriptCoreGetPropertyStringKeyHandle(
        key.borrowString(in: contextRef),
        on: ref, in: contextRef),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreGetIndexPropertyHandle(at: UInt32(index), on: ref, in: context.contextRef),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    javaScriptCoreSetStaticStringPropertyHandle(
      key,
      on: ref,
      to: value.ref,
      in: context.contextRef, attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing JSCPropertyStringKey,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextRef = context.contextRef
    return javaScriptCoreSetPropertyStringKeyHandle(
      key.borrowString(in: contextRef),
      on: ref,
      to: value.ref,
      in: contextRef, attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    javaScriptCoreSetIndexPropertyHandle(
      at: UInt32(index),
      on: ref,
      to: value.ref, in: context.contextRef)
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    javaScriptCoreDeleteStaticStringPropertyHandle(key, on: ref, in: context.contextRef)
  }

  public func deleteProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextRef = context.contextRef
    return javaScriptCoreDeletePropertyStringKeyHandle(
      key.borrowString(in: contextRef),
      on: ref, in: contextRef)
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    javaScriptCoreHasStaticStringPropertyHandle(key, on: ref, in: context.contextRef) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    let contextRef = context.contextRef
    return javaScriptCoreHasPropertyStringKeyHandle(
      key.borrowString(in: contextRef),
      on: ref, in: contextRef) ?? false
  }

  public func propertyNames(in context: borrowing JSCInstantContext) -> [String] {
    javaScriptCorePropertyNamesForHandle(on: ref, in: context.contextRef) ?? []
  }

  // MARK: Calling and construction

  public func call(
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreCallFunctionHandle(
        ref,
        this: nil,
        argumentHandles: arguments.map(\.ref), in: context.contextRef),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCValue,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreCallFunctionHandle(
        ref,
        this: thisValue.ref,
        argumentHandles: arguments.map(\.ref), in: context.contextRef),
      in: context
    )
  }

  public func construct(
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreConstructHandle(
        ref, argumentHandles: arguments.map(\.ref), in: context.contextRef),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  public func invokeMethod(
    _ name: borrowing JSCPropertyStringKey,
    arguments: [JSCCallArgument],
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  // MARK: Object conversion and classification

  public func toObject(
    in context: borrowing JSCInstantContext
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreToObjectHandle(ref, in: context.contextRef),
      in: context
    )
  }

  public func isArray(in context: borrowing JSCInstantContext) -> Bool {
    javaScriptCoreIsArrayHandle(ref, in: context.contextRef) ?? false
  }

  public func isDate(in context: borrowing JSCInstantContext) -> Bool {
    javaScriptCoreIsDateHandle(ref, in: context.contextRef) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing JSCValue,
    in context: borrowing JSCInstantContext
  ) -> Bool {
    javaScriptCoreIsInstanceOfHandle(
      ref,
      constructor: constructor.ref, in: context.contextRef) ?? false
  }

  public func isArrayBuffer(in context: borrowing JSCInstantContext) -> Bool {
    javaScriptCoreIsArrayBufferHandle(ref, in: context.contextRef)
  }

  public func isTypedArray(in context: borrowing JSCInstantContext) -> Bool {
    javaScriptCoreTypedArrayKindForHandle(ref, in: context.contextRef) != nil
  }
}

// MARK: - `#isolation` value conveniences
//
// The same operations addressed through the context actor. A requirement
// cannot carry a default argument, so these same-name overloads keep
// `value.getProperty("x")` callable; their results are adopted onto the
// context default scope exactly once (exception included), so they outlive the
// synchronous call instead of draining with a window.

extension JSCValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreGetStaticStringPropertyHandle(key, on: ref, in: context.contextRef),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    let contextRef = context.contextRef
    return bridgeJSCValueResult(
      javaScriptCoreGetPropertyStringKeyHandle(
        key.borrowString(in: contextRef),
        on: ref, in: contextRef),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreGetIndexPropertyHandle(at: UInt32(index), on: ref, in: context.contextRef),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    javaScriptCoreSetStaticStringPropertyHandle(
      key,
      on: ref,
      to: value.ref,
      in: context.contextRef, attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing JSCPropertyStringKey,
    to value: borrowing JSCValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextRef = context.contextRef
    return javaScriptCoreSetPropertyStringKeyHandle(
      key.borrowString(in: contextRef),
      on: ref,
      to: value.ref,
      in: contextRef, attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing JSCValue,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    javaScriptCoreSetIndexPropertyHandle(
      at: UInt32(index),
      on: ref,
      to: value.ref, in: context.contextRef)
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    javaScriptCoreDeleteStaticStringPropertyHandle(key, on: ref, in: context.contextRef)
  }

  public func deleteProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextRef = context.contextRef
    return javaScriptCoreDeletePropertyStringKeyHandle(
      key.borrowString(in: contextRef),
      on: ref, in: contextRef)
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    javaScriptCoreHasStaticStringPropertyHandle(key, on: ref, in: context.contextRef) ?? false
  }

  public func hasProperty(
    _ key: borrowing JSCPropertyStringKey,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    let contextRef = context.contextRef
    return javaScriptCoreHasPropertyStringKeyHandle(
      key.borrowString(in: contextRef),
      on: ref, in: contextRef) ?? false
  }

  public func propertyNames(in context: isolated JSCContext = #isolation) -> [String] {
    javaScriptCorePropertyNamesForHandle(on: ref, in: context.contextRef) ?? []
  }

  // MARK: Object conversion and classification

  public func toObject(in context: isolated JSCContext = #isolation) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreToObjectHandle(ref, in: context.contextRef),
      in: context
    )
  }

  public func isArray(in context: isolated JSCContext = #isolation) -> Bool {
    javaScriptCoreIsArrayHandle(ref, in: context.contextRef) ?? false
  }

  public func isDate(in context: isolated JSCContext = #isolation) -> Bool {
    javaScriptCoreIsDateHandle(ref, in: context.contextRef) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing JSCValue,
    in context: isolated JSCContext = #isolation
  ) -> Bool {
    javaScriptCoreIsInstanceOfHandle(
      ref,
      constructor: constructor.ref, in: context.contextRef) ?? false
  }

  public func isArrayBuffer(in context: isolated JSCContext = #isolation) -> Bool {
    javaScriptCoreIsArrayBufferHandle(ref, in: context.contextRef)
  }

  public func isTypedArray(in context: isolated JSCContext = #isolation) -> Bool {
    javaScriptCoreTypedArrayKindForHandle(ref, in: context.contextRef) != nil
  }
}

// MARK: - `#isolation` call conveniences
//
// The five call operations addressed through the context actor. Results are
// adopted onto the context default scope exactly once (exception included), so
// they outlive the call itself.

extension JSCValue {
  public func call(
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreCallFunctionHandle(
        ref,
        this: nil,
        argumentHandles: arguments.map(\.ref), in: context.contextRef),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing JSCValue,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreCallFunctionHandle(
        ref,
        this: thisValue.ref,
        argumentHandles: arguments.map(\.ref), in: context.contextRef),
      in: context
    )
  }

  public func construct(
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    bridgeJSCValueResult(
      javaScriptCoreConstructHandle(
        ref, argumentHandles: arguments.map(\.ref), in: context.contextRef),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    switch bridgeJSCValueResult(
      javaScriptCoreGetStaticStringPropertyHandle(name, on: ref, in: context.contextRef),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeJSCValueResult(
        javaScriptCoreCallFunctionHandle(
          method.ref,
          this: ref,
          argumentHandles: arguments.map(\.ref), in: context.contextRef),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing JSCPropertyStringKey,
    arguments: [JSCCallArgument] = [],
    in context: isolated JSCContext = #isolation
  ) -> JSResult<JSCValue> {
    switch bridgeJSCValueResult(
      javaScriptCoreGetPropertyStringKeyHandle(
        name.borrowString(in: context.contextRef),
        on: ref, in: context.contextRef),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeJSCValueResult(
        javaScriptCoreCallFunctionHandle(
          method.ref,
          this: ref,
          argumentHandles: arguments.map(\.ref), in: context.contextRef),
        in: context
      )
    }
  }
}

// MARK: - Engine-local result bridging
//
// Every value operation drives the JSC driver and adopts its engine-returned
// ref onto the calling arena exactly once — the exception path included.
// The adoption target belongs to the engine, so this helper lives with it (the
// former core bridge is gone).

private func bridgeJSCValueResult(
  _ result: JSResult<JSValueRef>?,
  in context: borrowing JSCInstantContext
) -> JSResult<JSCValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let ref):
    return .value(context.adoptCreatedHandle(ref))
  case .exception(let ref):
    return .exception(context.adoptCreatedHandle(ref))
  }
}

private func bridgeJSCValueResult(
  _ result: JSResult<JSValueRef>?,
  in context: isolated JSCContext
) -> JSResult<JSCValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let ref):
    return .value(context.adoptCreatedHandle(ref))
  case .exception(let ref):
    return .exception(context.adoptCreatedHandle(ref))
  }
}
