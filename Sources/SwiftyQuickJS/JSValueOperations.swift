import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Mirror of the JavaScriptCore file: every operation drives the `QuickJS`
// raw-value statics directly and adopts each engine-returned value onto the
// passed scope's arena exactly once — the exception path included. QuickJS
// hands back a new reference (+1) for each result, so adopting it is what the
// arena drain later settles with `JS_FreeValue`; no `JS_DupValue` happens on
// this path. The `#isolation` forms below adopt onto the context default scope
// instead; both
// live here because the value type is the engine's.

extension QJSValue {
  // MARK: Property reads

  @_lifetime(borrow context)
  public func getProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSGetStaticStringProperty(key, on: value, in: context.contextRef),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSGetProperty(
        atom: key.borrowAtom(in: context.contextRef),
        on: value,
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func getProperty(
    at index: Int,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSGetIndexProperty(at: UInt32(index), on: value, in: context.contextRef),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSSetStaticStringProperty(
      key,
      on: self.value,
      to: value.value,
      in: context.contextRef,
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing QJSPropertyStringKey,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSSetProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: self.value,
      to: value.value,
      in: context.contextRef,
      attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSSetIndexProperty(
      at: UInt32(index),
      on: self.value,
      to: value.value,
      in: context.contextRef
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSDeleteStaticStringProperty(key, on: value, in: context.contextRef)
  }

  public func deleteProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSDeleteProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSHasStaticStringProperty(key, on: value, in: context.contextRef) ?? false
  }

  public func hasProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSHasProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    ) ?? false
  }

  public func propertyNames(in context: borrowing QJSInstantContext) -> [String] {
    quickJSPropertyNames(on: value, in: context.contextRef) ?? []
  }

  // MARK: Calling and construction

  @_lifetime(borrow context)
  public func call(
    arguments: Span<QJSCallArgument>,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSCallFunction(
        value,
        this: nil,
        arguments: quickJSRawArguments(arguments),
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func call(
    this thisValue: borrowing QJSValue,
    arguments: Span<QJSCallArgument>,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSCallFunction(
        value,
        this: thisValue.value,
        arguments: quickJSRawArguments(arguments),
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func construct(
    arguments: Span<QJSCallArgument>,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSConstruct(
        value,
        arguments: quickJSRawArguments(arguments),
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func invokeMethod(
    _ name: StaticString,
    arguments: Span<QJSCallArgument>,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  @_lifetime(borrow context)
  public func invokeMethod(
    _ name: borrowing QJSPropertyStringKey,
    arguments: Span<QJSCallArgument>,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  // MARK: Object conversion and classification

  @_lifetime(borrow context)
  public func toObject(
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSToObject(value, in: context.contextRef),
      in: context
    )
  }

  public func isArray(in context: borrowing QJSInstantContext) -> Bool {
    quickJSIsArray(value, in: context.contextRef) ?? false
  }

  public func isDate(in context: borrowing QJSInstantContext) -> Bool {
    quickJSIsDate(value, in: context.contextRef) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    quickJSIsInstanceOf(
      value,
      constructor: constructor.value,
      in: context.contextRef
    ) ?? false
  }

  public func isArrayBuffer(in context: borrowing QJSInstantContext) -> Bool {
    quickJSIsArrayBuffer(value, in: context.contextRef)
  }

  public func isTypedArray(in context: borrowing QJSInstantContext) -> Bool {
    quickJSTypedArrayKind(value, in: context.contextRef) != nil
  }
}

// MARK: - `#isolation` value conveniences
//
// The same operations addressed through the context actor. A requirement
// cannot carry a default argument, so these same-name overloads keep
// `value.getProperty("x")` callable; their results are adopted onto the
// context default scope exactly once (exception included), so they outlive the
// synchronous call instead of draining with a window.

extension QJSValue {
  // MARK: Property reads

  @_lifetime(borrow context)
  public func getProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSGetStaticStringProperty(key, on: value, in: context.contextRef),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSGetProperty(
        atom: key.borrowAtom(in: context.contextRef),
        on: value,
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func getProperty(
    at index: Int,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSGetIndexProperty(at: UInt32(index), on: value, in: context.contextRef),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSSetStaticStringProperty(
      key,
      on: self.value,
      to: value.value,
      in: context.contextRef,
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing QJSPropertyStringKey,
    to value: borrowing QJSValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSSetProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: self.value,
      to: value.value,
      in: context.contextRef,
      attributes: attributes
    )
  }

  public func setProperty(
    at index: Int,
    to value: borrowing QJSValue,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSSetIndexProperty(
      at: UInt32(index),
      on: self.value,
      to: value.value,
      in: context.contextRef
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSDeleteStaticStringProperty(key, on: value, in: context.contextRef)
  }

  public func deleteProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSDeleteProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSHasStaticStringProperty(key, on: value, in: context.contextRef) ?? false
  }

  public func hasProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSHasProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    ) ?? false
  }

  public func propertyNames(in context: isolated QJSContext = #isolation) -> [String] {
    quickJSPropertyNames(on: value, in: context.contextRef) ?? []
  }

  // MARK: Object conversion and classification

  @_lifetime(borrow context)
  public func toObject(in context: isolated QJSContext = #isolation) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSToObject(value, in: context.contextRef),
      in: context
    )
  }

  public func isArray(in context: isolated QJSContext = #isolation) -> Bool {
    quickJSIsArray(value, in: context.contextRef) ?? false
  }

  public func isDate(in context: isolated QJSContext = #isolation) -> Bool {
    quickJSIsDate(value, in: context.contextRef) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing QJSValue,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    quickJSIsInstanceOf(
      value,
      constructor: constructor.value,
      in: context.contextRef
    ) ?? false
  }

  public func isArrayBuffer(in context: isolated QJSContext = #isolation) -> Bool {
    quickJSIsArrayBuffer(value, in: context.contextRef)
  }

  public func isTypedArray(in context: isolated QJSContext = #isolation) -> Bool {
    quickJSTypedArrayKind(value, in: context.contextRef) != nil
  }
}

// MARK: - `#isolation` call conveniences
//
// The five call operations addressed through the context actor. Results are
// adopted onto the context default scope exactly once (exception included), so
// they outlive the call itself.

extension QJSValue {
  @_lifetime(borrow context)
  public func call(
    arguments: Span<QJSCallArgument> = Span(),
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSCallFunction(
        value,
        this: nil,
        arguments: quickJSRawArguments(arguments),
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func call(
    this thisValue: borrowing QJSValue,
    arguments: Span<QJSCallArgument> = Span(),
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSCallFunction(
        value,
        this: thisValue.value,
        arguments: quickJSRawArguments(arguments),
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func construct(
    arguments: Span<QJSCallArgument> = Span(),
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      quickJSConstruct(
        value,
        arguments: quickJSRawArguments(arguments),
        in: context.contextRef
      ),
      in: context
    )
  }

  @_lifetime(borrow context)
  public func invokeMethod(
    _ name: StaticString,
    arguments: Span<QJSCallArgument> = Span(),
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    switch bridgeQJSValueResult(
      quickJSGetStaticStringProperty(name, on: value, in: context.contextRef),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeQJSValueResult(
        quickJSCallFunction(
          method.value,
          this: value,
          arguments: quickJSRawArguments(arguments),
          in: context.contextRef
        ),
        in: context
      )
    }
  }

  @_lifetime(borrow context)
  public func invokeMethod(
    _ name: borrowing QJSPropertyStringKey,
    arguments: Span<QJSCallArgument> = Span(),
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    switch bridgeQJSValueResult(
      quickJSGetProperty(
        atom: name.borrowAtom(in: context.contextRef),
        on: value,
        in: context.contextRef
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeQJSValueResult(
        quickJSCallFunction(
          method.value,
          this: value,
          arguments: quickJSRawArguments(arguments),
          in: context.contextRef
        ),
        in: context
      )
    }
  }
}

// MARK: - Engine-local result bridging
//
// Every value operation drives the QuickJS engine statics and adopts the
// engine-returned reference onto the calling arena exactly once — the
// exception path included. The adoption target belongs to the engine, so this
// helper lives with it.

private func quickJSRawArguments(
  _ arguments: Span<QJSCallArgument>
) -> [CQuickJSValue] {
  var values: [CQuickJSValue] = []
  values.reserveCapacity(arguments.count)
  for index in 0..<arguments.count {
    values.append(arguments[index].value)
  }
  return values
}

@_lifetime(borrow context)
private func bridgeQJSValueResult(
  _ result: consuming JSResult<CQuickJSValue>?,
  in context: borrowing QJSInstantContext
) -> JSResult<QJSValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let created):
    return .value(context.adoptCreated(created))
  case .exception(let thrown):
    return .exception(context.adoptCreated(thrown))
  }
}

@_lifetime(borrow context)
private func bridgeQJSValueResult(
  _ result: consuming JSResult<CQuickJSValue>?,
  in context: isolated QJSContext
) -> JSResult<QJSValue> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let created):
    return .value(context.adoptCreated(created))
  case .exception(let thrown):
    return .exception(context.adoptCreated(thrown))
  }
}
