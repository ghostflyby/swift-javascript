extension JSInstantContext {
  private func ensureSameVM(_ value: borrowing JSValue) {
    let valueHandle = value.valueHandle()
    guard
      let valueGroup = JavaScriptCoreEngine.contextGroupRef(from: valueHandle),
      let contextGroup = JavaScriptCoreEngine.contextGroupRef(from: driverContextHandle)
    else {
      preconditionFailure("JSValue bridge could not resolve context group")
    }
    precondition(
      valueGroup == contextGroup,
      "Cross-VM JSValue operation is not allowed; pass a context from the same JSVirtualMachine"
    )
  }

  func valueHandle(for value: borrowing JSValue) -> JSValueHandle<JavaScriptCoreEngine> {
    ensureSameVM(value)
    return value.valueHandle()
  }

  func bridgeResult(
    _ handleResult: JSResultPayload<JSValueHandle<JavaScriptCoreEngine>>?
  ) -> JSResult {
    .from(handleResult: handleResult)
  }

  func toBoolean(_ value: borrowing JSValue) -> Bool {
    JavaScriptCoreEngine.toBoolean(value.ref, in: globalContextRef)
  }

  func toNumber(_ value: borrowing JSValue) -> Double {
    JavaScriptCoreEngine.toNumber(value.ref, in: globalContextRef)
  }

  func toString(_ value: borrowing JSValue) -> String {
    JavaScriptCoreEngine.toString(value.ref, in: globalContextRef) ?? ""
  }

  func looselyEquals(_ lhs: borrowing JSValue, _ rhs: borrowing JSValue) -> Bool {
    JavaScriptCoreEngine.valueEquals(lhs.ref, rhs.ref, in: globalContextRef)
  }

  func strictlyEquals(_ lhs: borrowing JSValue, _ rhs: borrowing JSValue) -> Bool {
    JavaScriptCoreEngine.valueStrictEquals(lhs.ref, rhs.ref, in: globalContextRef)
  }

  func encodeArguments<each A: JSValueEncodable>(
    _ arguments: repeat each A
  ) -> [JSValueHandle<JavaScriptCoreEngine>] {
    var values: [JSValueHandle<JavaScriptCoreEngine>] = []
    values.reserveCapacity(countTypePack(repeat (each A).self))

    func appendArgument<T: JSValueEncodable>(_ argument: T) {
      let encoded = (try? argument.tryEncode(in: self)) ?? JSValue(undefinedIn: self)
      values.append(valueHandle(for: encoded))
    }

    repeat appendArgument(each arguments)
    return values
  }

  func call(
    function: borrowing JSValue,
    this thisValueHandle: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.callFunctionHandle(
        valueHandle(for: function),
        this: thisValueHandle,
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func call(function: borrowing JSValue) -> JSResult {
    call(function: function, this: nil, arguments: [])
  }

  func call(
    function: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult {
    call(function: function, this: nil, arguments: arguments)
  }

  func call(
    function: borrowing JSValue,
    this thisValue: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = []
  ) -> JSResult {
    call(
      function: function,
      this: valueHandle(for: thisValue),
      arguments: arguments
    )
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue,
    arguments: repeat each A
  ) -> JSResult {
    call(function: function, arguments: encodeArguments(repeat each arguments))
  }

  func call<each A: JSValueEncodable>(
    function: borrowing JSValue,
    this thisValue: borrowing JSValue,
    arguments: repeat each A
  ) -> JSResult {
    call(
      function: function,
      this: thisValue,
      arguments: encodeArguments(repeat each arguments)
    )
  }

  func construct(
    constructor: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.constructHandle(
        valueHandle(for: constructor),
        arguments: arguments,
        in: driverContextHandle
      ))
  }

  func construct(constructor: borrowing JSValue) -> JSResult {
    construct(constructor: constructor, arguments: [])
  }

  func construct<each A: JSValueEncodable>(
    constructor: borrowing JSValue,
    arguments: repeat each A
  ) -> JSResult {
    construct(constructor: constructor, arguments: encodeArguments(repeat each arguments))
  }

  func getStringProperty(_ key: String, on object: borrowing JSValue) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.getStringPropertyHandle(
        key,
        on: valueHandle(for: object),
        in: driverContextHandle
      ))
  }

  func setStringProperty(
    _ key: String,
    on object: borrowing JSValue,
    to value: borrowing JSValue,
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
    on object: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>]
  ) -> JSResult {
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

  func invokeMethod(_ name: String, on object: borrowing JSValue) -> JSResult {
    invokeMethod(name, on: object, arguments: [])
  }

  func invokeMethod<each A: JSValueEncodable>(
    _ name: String,
    on object: borrowing JSValue,
    arguments: repeat each A
  ) -> JSResult {
    invokeMethod(name, on: object, arguments: encodeArguments(repeat each arguments))
  }

  func toObject(_ value: borrowing JSValue) -> JSResult {
    bridgeResult(
      JavaScriptCoreEngine.toObjectHandle(
        valueHandle(for: value),
        in: driverContextHandle
      ))
  }

  func isArray(_ value: borrowing JSValue) -> Bool {
    JavaScriptCoreEngine.isArrayHandle(valueHandle(for: value), in: driverContextHandle) ?? false
  }

  func isDate(_ value: borrowing JSValue) -> Bool {
    JavaScriptCoreEngine.isDateHandle(valueHandle(for: value), in: driverContextHandle) ?? false
  }

  func isInstanceOf(
    _ value: borrowing JSValue,
    constructor: borrowing JSValue
  ) -> Bool {
    JavaScriptCoreEngine.isInstanceOfHandle(
      valueHandle(for: value),
      constructor: valueHandle(for: constructor),
      in: driverContextHandle
    ) ?? false
  }
}
