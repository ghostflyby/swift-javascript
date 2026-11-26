import SwiftJavaScript

// MARK: - Property, object, and invocation surface (S5)
//
// Mirror of the JavaScriptCore file: every operation drives the `QJSEngine`
// raw-value statics directly and adopts each engine-returned value onto the
// passed scope's arena exactly once — the exception path included. QuickJS
// hands back a new reference (+1) for each result, so adopting it is what the
// arena drain later settles with `JS_FreeValue`; no `JS_DupValue` happens on
// this path. The `#isolation` forms below adopt onto the context default scope
// instead; both
// live here because the value type is the engine's.

extension QJSValue {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.getStaticStringProperty(key, on: value, in: context.contextRef),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.getProperty(
        atom: key.borrowAtom(in: context.contextRef),
        on: value,
        in: context.contextRef
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.getIndexProperty(at: UInt32(index), on: value, in: context.contextRef),
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
    QJSEngine.setStaticStringProperty(
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
    QJSEngine.setProperty(
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
    QJSEngine.setIndexProperty(
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
    QJSEngine.deleteStaticStringProperty(key, on: value, in: context.contextRef)
  }

  public func deleteProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    QJSEngine.deleteProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    QJSEngine.hasStaticStringProperty(key, on: value, in: context.contextRef) ?? false
  }

  public func hasProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    QJSEngine.hasProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    ) ?? false
  }

  public func propertyNames(in context: borrowing QJSInstantContext) -> [String] {
    QJSEngine.propertyNames(on: value, in: context.contextRef) ?? []
  }

  // MARK: Calling and construction

  public func call(
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.callFunction(
        value,
        this: nil,
        arguments: arguments.map(\.value),
        in: context.contextRef
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSValue,
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.callFunction(
        value,
        this: thisValue.value,
        arguments: arguments.map(\.value),
        in: context.contextRef
      ),
      in: context
    )
  }

  public func construct(
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.construct(
        value,
        arguments: arguments.map(\.value),
        in: context.contextRef
      ),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [QJSCallArgument],
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    switch getProperty(name, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return method.call(this: self, arguments: arguments, in: context)
    }
  }

  public func invokeMethod(
    _ name: borrowing QJSPropertyStringKey,
    arguments: [QJSCallArgument],
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

  public func toObject(
    in context: borrowing QJSInstantContext
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.toObject(value, in: context.contextRef),
      in: context
    )
  }

  public func isArray(in context: borrowing QJSInstantContext) -> Bool {
    QJSEngine.isArray(value, in: context.contextRef) ?? false
  }

  public func isDate(in context: borrowing QJSInstantContext) -> Bool {
    QJSEngine.isDate(value, in: context.contextRef) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) -> Bool {
    QJSEngine.isInstanceOf(
      value,
      constructor: constructor.value,
      in: context.contextRef
    ) ?? false
  }

  public func isArrayBuffer(in context: borrowing QJSInstantContext) -> Bool {
    QJSEngine.isArrayBuffer(value, in: context.contextRef)
  }

  public func isTypedArray(in context: borrowing QJSInstantContext) -> Bool {
    QJSEngine.typedArrayKind(value, in: context.contextRef) != nil
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

  public func getProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.getStaticStringProperty(key, on: value, in: context.contextRef),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.getProperty(
        atom: key.borrowAtom(in: context.contextRef),
        on: value,
        in: context.contextRef
      ),
      in: context
    )
  }

  public func getProperty(
    at index: Int,
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.getIndexProperty(at: UInt32(index), on: value, in: context.contextRef),
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
    QJSEngine.setStaticStringProperty(
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
    QJSEngine.setProperty(
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
    QJSEngine.setIndexProperty(
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
    QJSEngine.deleteStaticStringProperty(key, on: value, in: context.contextRef)
  }

  public func deleteProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    QJSEngine.deleteProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    QJSEngine.hasStaticStringProperty(key, on: value, in: context.contextRef) ?? false
  }

  public func hasProperty(
    _ key: borrowing QJSPropertyStringKey,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    QJSEngine.hasProperty(
      atom: key.borrowAtom(in: context.contextRef),
      on: value,
      in: context.contextRef
    ) ?? false
  }

  public func propertyNames(in context: isolated QJSContext = #isolation) -> [String] {
    QJSEngine.propertyNames(on: value, in: context.contextRef) ?? []
  }

  // MARK: Object conversion and classification

  public func toObject(in context: isolated QJSContext = #isolation) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.toObject(value, in: context.contextRef),
      in: context
    )
  }

  public func isArray(in context: isolated QJSContext = #isolation) -> Bool {
    QJSEngine.isArray(value, in: context.contextRef) ?? false
  }

  public func isDate(in context: isolated QJSContext = #isolation) -> Bool {
    QJSEngine.isDate(value, in: context.contextRef) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing QJSValue,
    in context: isolated QJSContext = #isolation
  ) -> Bool {
    QJSEngine.isInstanceOf(
      value,
      constructor: constructor.value,
      in: context.contextRef
    ) ?? false
  }

  public func isArrayBuffer(in context: isolated QJSContext = #isolation) -> Bool {
    QJSEngine.isArrayBuffer(value, in: context.contextRef)
  }

  public func isTypedArray(in context: isolated QJSContext = #isolation) -> Bool {
    QJSEngine.typedArrayKind(value, in: context.contextRef) != nil
  }
}

// MARK: - `#isolation` call conveniences
//
// The five call operations addressed through the context actor. Results are
// adopted onto the context default scope exactly once (exception included), so
// they outlive the call itself.

extension QJSValue {
  public func call(
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.callFunction(
        value,
        this: nil,
        arguments: arguments.map(\.value),
        in: context.contextRef
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing QJSValue,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.callFunction(
        value,
        this: thisValue.value,
        arguments: arguments.map(\.value),
        in: context.contextRef
      ),
      in: context
    )
  }

  public func construct(
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    bridgeQJSValueResult(
      QJSEngine.construct(
        value,
        arguments: arguments.map(\.value),
        in: context.contextRef
      ),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    switch bridgeQJSValueResult(
      QJSEngine.getStaticStringProperty(name, on: value, in: context.contextRef),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeQJSValueResult(
        QJSEngine.callFunction(
          method.value,
          this: value,
          arguments: arguments.map(\.value),
          in: context.contextRef
        ),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing QJSPropertyStringKey,
    arguments: [QJSCallArgument] = [],
    in context: isolated QJSContext = #isolation
  ) -> JSResult<QJSValue> {
    switch bridgeQJSValueResult(
      QJSEngine.getProperty(
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
        QJSEngine.callFunction(
          method.value,
          this: value,
          arguments: arguments.map(\.value),
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

private func bridgeQJSValueResult(
  _ result: JSResult<CQuickJSValue>?,
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

private func bridgeQJSValueResult(
  _ result: JSResult<CQuickJSValue>?,
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
