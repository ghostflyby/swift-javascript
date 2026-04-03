protocol _JSValueBridgeAdapter {
  associatedtype Engine: JSEngine

  func valueHandle(
    for value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSValueHandle<Engine>

  func bridgeResult(_ handleResult: JSResultPayload<JSValueHandle<Engine>>?) -> JSResult
}

struct JavaScriptCoreValueBridgeAdapter: _JSValueBridgeAdapter {
  typealias Engine = JavaScriptCoreEngine

  private func ensureSameVM(
    _ value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) {
    let valueHandle = value.valueHandle()
    guard
      let valueGroup = JavaScriptCoreEngine.contextGroupRef(from: valueHandle),
      let contextGroup = JavaScriptCoreEngine.contextGroupRef(
        from: context.driverContextHandle)
    else {
      preconditionFailure("JSValue bridge could not resolve context group")
    }
    precondition(
      valueGroup == contextGroup,
      "Cross-VM JSValue operation is not allowed; pass a context from the same JSVirtualMachine"
    )
  }

  func type(of value: borrowing JSValue, in context: borrowing JSInstantContext) -> JSType {
    JavaScriptCoreEngine.valueType(of: value.ref, in: context.globalContextRef)
  }

  func isUndefined(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isUndefined(value.ref, in: context.globalContextRef)
  }

  func isNull(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isNull(value.ref, in: context.globalContextRef)
  }

  func isBoolean(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isBoolean(value.ref, in: context.globalContextRef)
  }

  func isNumber(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isNumber(value.ref, in: context.globalContextRef)
  }

  func isString(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isString(value.ref, in: context.globalContextRef)
  }

  func isSymbol(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isSymbol(value.ref, in: context.globalContextRef)
  }

  func isObject(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isObject(value.ref, in: context.globalContextRef)
  }

  func isBigInt(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isBigInt(value.ref, in: context.globalContextRef)
  }

  func toBoolean(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.toBoolean(value.ref, in: context.globalContextRef)
  }

  func toNumber(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Double {
    JavaScriptCoreEngine.toNumber(value.ref, in: context.globalContextRef)
  }

  func toString(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> String {
    JavaScriptCoreEngine.toString(value.ref, in: context.globalContextRef) ?? ""
  }

  func looselyEquals(
    _ lhs: borrowing JSValue,
    _ rhs: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    JavaScriptCoreEngine.valueEquals(lhs.ref, rhs.ref, in: context.globalContextRef)
  }

  func strictlyEquals(
    _ lhs: borrowing JSValue,
    _ rhs: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    JavaScriptCoreEngine.valueStrictEquals(lhs.ref, rhs.ref, in: context.globalContextRef)
  }

  func encodeArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> [JSValueHandle<JavaScriptCoreEngine>] {
    var values: [JSValueHandle<JavaScriptCoreEngine>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded = (try? argument.tryEncode(in: context)) ?? JSValue(undefinedIn: context)
      values.append(valueHandle(for: encoded, in: context))
    }

    repeat appendArgument(each arguments)
    return values
  }

  func valueHandle(
    for value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSValueHandle<JavaScriptCoreEngine> {
    ensureSameVM(value, in: context)
    return value.valueHandle()
  }

  func bridgeResult(
    _ handleResult: JSResultPayload<JSValueHandle<JavaScriptCoreEngine>>?
  ) -> JSResult {
    .from(handleResult: handleResult)
  }

  func call(
    function: borrowing JSValue,
    this thisValueHandle: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.callFunctionHandle(
        valueHandle(for: function, in: context),
        this: thisValueHandle,
        arguments: arguments,
        in: context.driverContextHandle
      ))
  }

  func call(
    function: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    call(function: function, this: nil, arguments: [], in: context)
  }

  func call(
    function: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    call(function: function, this: nil, arguments: arguments, in: context)
  }

  func call(
    function: borrowing JSValue,
    this thisValue: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = [],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    call(
      function: function,
      this: valueHandle(for: thisValue, in: context),
      arguments: arguments,
      in: context
    )
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    call(
      function: function,
      arguments: encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue,
    this thisValue: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    call(
      function: function,
      this: thisValue,
      arguments: encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  func construct(
    constructor: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.constructHandle(
        valueHandle(for: constructor, in: context),
        arguments: arguments,
        in: context.driverContextHandle
      ))
  }

  func construct(
    constructor: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    construct(constructor: constructor, arguments: [], in: context)
  }

  func construct<each A: JSValueEncodable>(
    constructor: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    construct(
      constructor: constructor,
      arguments: encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  func getStringProperty(
    _ key: String,
    on object: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.getStringPropertyHandle(
        key,
        on: valueHandle(for: object, in: context),
        in: context.driverContextHandle
      ))
  }

  func setStringProperty(
    _ key: String,
    on object: borrowing JSValue,
    to value: borrowing JSValue,
    in context: borrowing JSInstantContext,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    JavaScriptCoreEngine.setStringPropertyHandle(
      key,
      on: valueHandle(for: object, in: context),
      to: valueHandle(for: value, in: context),
      in: context.driverContextHandle,
      attributes: attributes
    )
  }

  func invokeMethod(
    _ name: String,
    on object: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    switch getStringProperty(name, on: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return call(
        function: method,
        this: valueHandle(for: object, in: context),
        arguments: arguments,
        in: context
      )
    }
  }

  func invokeMethod(
    _ name: String,
    on object: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    invokeMethod(name, on: object, arguments: [], in: context)
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: String,
    on object: borrowing JSValue,
    arguments: repeat each A,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    invokeMethod(
      name,
      on: object,
      arguments: encodeArguments(repeat each arguments, in: context),
      in: context
    )
  }

  func toObject(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.toObjectHandle(
        valueHandle(for: value, in: context),
        in: context.driverContextHandle
      ))
  }

  func isArray(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isArrayHandle(
      valueHandle(for: value, in: context),
      in: context.driverContextHandle
    ) ?? false
  }

  func isDate(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreEngine.isDateHandle(
      valueHandle(for: value, in: context),
      in: context.driverContextHandle
    ) ?? false
  }

  func isInstanceOf(
    _ value: borrowing JSValue,
    constructor: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    JavaScriptCoreEngine.isInstanceOfHandle(
      valueHandle(for: value, in: context),
      constructor: valueHandle(for: constructor, in: context),
      in: context.driverContextHandle
    ) ?? false
  }
}

extension JSInstantContext {
  var valueBridgeAdapter: JavaScriptCoreValueBridgeAdapter {
    JavaScriptCoreValueBridgeAdapter()
  }
}
