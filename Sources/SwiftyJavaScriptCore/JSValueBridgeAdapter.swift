protocol _JSValueBridgeAdapter {
  associatedtype Engine: JSEngine

  func valueHandle(
    for value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSValueHandle<Engine>

  func bridgeResult(_ handleResult: JSResultHandle<Engine>?) -> JSResult
}

struct JavaScriptCoreValueBridgeAdapter: _JSValueBridgeAdapter {
  typealias Engine = JavaScriptCoreEngine

  func valueHandle(
    for value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSValueHandle<JavaScriptCoreEngine> {
    value.valueHandle(in: context)
  }

  func bridgeResult(_ handleResult: JSResultHandle<JavaScriptCoreEngine>?) -> JSResult {
    .from(handleResult: handleResult)
  }

  func call(
    function: borrowing JSValue,
    this thisValueHandle: JSValueHandle<JavaScriptCoreEngine>?,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreBackendDriver.callFunctionHandle(
        valueHandle(for: function, in: context),
        this: thisValueHandle,
        arguments: arguments,
        in: context.driverContextHandle
      ))
  }

  func construct(
    constructor: borrowing JSValue,
    arguments: [JSValueHandle<JavaScriptCoreEngine>],
    in context: borrowing JSInstantContext
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreBackendDriver.constructHandle(
        valueHandle(for: constructor, in: context),
        arguments: arguments,
        in: context.driverContextHandle
      ))
  }

  func getStringProperty(
    _ key: String,
    on object: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> JSResult {
    bridgeResult(
      JavaScriptCoreBackendDriver.getStringPropertyHandle(
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
    JavaScriptCoreBackendDriver.setStringPropertyHandle(
      key,
      on: valueHandle(for: object, in: context),
      to: valueHandle(for: value, in: context),
      in: context.driverContextHandle,
      attributes: attributes
    )
  }

  func toObject(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> JSResult {
    bridgeResult(
      JavaScriptCoreBackendDriver.toObjectHandle(
        valueHandle(for: value, in: context),
        in: context.driverContextHandle
      ))
  }

  func isArray(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isArrayHandle(
      valueHandle(for: value, in: context),
      in: context.driverContextHandle
    ) ?? false
  }

  func isDate(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Bool {
    JavaScriptCoreBackendDriver.isDateHandle(
      valueHandle(for: value, in: context),
      in: context.driverContextHandle
    ) ?? false
  }

  func isInstanceOf(
    _ value: borrowing JSValue,
    constructor: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) -> Bool {
    JavaScriptCoreBackendDriver.isInstanceOfHandle(
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