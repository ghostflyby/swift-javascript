extension JSInstantContext {
  private func ensureSameVM(_ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) {
    let valueHandle = value.valueHandle()
    guard
      let valueGroup = JavaScriptCoreEngine.contextGroupRef(from: valueHandle),
      let contextGroup = JavaScriptCoreEngine.contextGroupRef(from: driverContextHandle)
    else {
      preconditionFailure(
        "SwiftJavaScript.JSValue<JavaScriptCoreEngine> bridge could not resolve context group")
    }
    precondition(
      valueGroup == contextGroup,
      "Cross-VM SwiftJavaScript.JSValue<JavaScriptCoreEngine> operation is not allowed; pass a context from the same JSVirtualMachine"
    )
  }

  func valueHandle(for value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>)
    -> JSValueHandle<
      JavaScriptCoreEngine
    >
  {
    ensureSameVM(value)
    return value.valueHandle()
  }

  func bridgeResult(
    _ handleResult: JSResult<JSValueHandle<JavaScriptCoreEngine>>?
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    .from(handleResult: handleResult)
  }

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

  func encodeArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A
  ) -> [JSValueHandle<JavaScriptCoreEngine>] {
    var values: [JSValueHandle<JavaScriptCoreEngine>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded =
        (try? argument.tryEncode(in: self))
        ?? SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: self)
      values.append(valueHandle(for: encoded))
    }

    repeat appendArgument(each arguments)
    return values
  }

  func call(
    function: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    this thisValueHandle: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    bridgeResult(
      JavaScriptCoreEngine.callFunctionHandle(
        valueHandle(for: function),
        this: thisValueHandle,
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func call(function: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) -> JSResult<
    SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  > {
    call(function: function, this: nil, arguments: [])
  }

  func call(
    function: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    call(function: function, this: nil, arguments: arguments)
  }

  func call(
    function: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    this thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = []
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    call(
      function: function,
      this: valueHandle(for: thisValue),
      arguments: arguments
    )
  }

  func call<each A: JSValueEncodable>(
    function: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: repeat each A
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    call(function: function, arguments: encodeArguments(repeat each arguments))
  }

  func call<each A: JSValueEncodable>(
    function: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    this thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: repeat each A
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    call(
      function: function,
      this: thisValue,
      arguments: encodeArguments(repeat each arguments)
    )
  }

  func construct(
    constructor: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    bridgeResult(
      JavaScriptCoreEngine.constructHandle(
        valueHandle(for: constructor),
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func construct(constructor: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) -> JSResult<
    SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  > {
    construct(constructor: constructor, arguments: [])
  }

  func construct<each A: JSValueEncodable>(
    constructor: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: repeat each A
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    construct(constructor: constructor, arguments: encodeArguments(repeat each arguments))
  }

  func getStringProperty(
    _ key: String, on object: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  )
    -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>
  {
    bridgeResult(
      JavaScriptCoreEngine.getStringPropertyHandle(
        key,
        on: valueHandle(for: object),
        in: driverContextHandle
      ))
  }

  func setStringProperty(
    _ key: String,
    on object: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    to value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    JavaScriptCoreEngine.setStringPropertyHandle(
      key,
      on: valueHandle(for: object),
      to: valueHandle(for: value),
      in: driverContextHandle,
      attributes: attributes
    )
  }

  func invokeMethod(
    _ name: String,
    on object: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    switch getStringProperty(name, on: object) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return call(
        function: method,
        this: valueHandle(for: object),
        arguments: arguments
      )
    }
  }

  func invokeMethod(
    _ name: String, on object: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  )
    -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>
  {
    invokeMethod(name, on: object, arguments: [])
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: String,
    on object: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    arguments: repeat each A
  ) -> JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>> {
    invokeMethod(name, on: object, arguments: encodeArguments(repeat each arguments))
  }

  func toObject(_ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) -> JSResult<
    SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  > {
    bridgeResult(
      JavaScriptCoreEngine.toObjectHandle(
        valueHandle(for: value),
        in: driverContextHandle
      ))
  }

  func isArray(_ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) -> Bool {
    JavaScriptCoreEngine.isArrayHandle(valueHandle(for: value), in: driverContextHandle) ?? false
  }

  func isDate(_ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>) -> Bool {
    JavaScriptCoreEngine.isDateHandle(valueHandle(for: value), in: driverContextHandle) ?? false
  }

  func isInstanceOf(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    constructor: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> Bool {
    JavaScriptCoreEngine.isInstanceOfHandle(
      valueHandle(for: value),
      constructor: valueHandle(for: constructor),
      in: driverContextHandle
    ) ?? false
  }
}
