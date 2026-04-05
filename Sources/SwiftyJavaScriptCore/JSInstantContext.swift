/// A lightweight callback-facing context used for synchronous JavaScript interactions.
///
/// `JSInstantContext` mirrors the user-facing API surface of `JSContext` for callback code,
/// but avoids actor hops so callbacks can run in a tight synchronous path.
///
/// Design intent:
/// - Provide a lightweight substitute for `JSContext` inside callback-heavy code paths.
/// - Keep API semantics aligned with `JSContext` (`make*`, global property helpers,
///   `evaluateScript`, etc.).
///
/// Non-goals:
/// - It is not a generic low-level bridge layer.
/// - Backend/handle/raw-context orchestration should stay in backend adapters or
///   local call-site helpers unless it is part of this callback-facing API surface.
public typealias JSInstantContext = JSEngineInstantContext<JavaScriptCoreEngine>

extension JSEngineInstantContext where E == JavaScriptCoreEngine {
  init(ctx: JavaScriptCoreContextRef) {
    self.init(
      handle: JavaScriptCoreContextHandle(borrowing: ctx)
    )
  }

  public var globalContextRef: JavaScriptCoreGlobalContextRef {
    driverContextHandle.ref
  }
}

extension JSEngineInstantContext where E == JavaScriptCoreEngine {
  private func makeFunctionHandle(
    named name: String,
    callback: @escaping JSFunctionCallback
  ) -> JSValueHandle<JavaScriptCoreEngine> {
    let rawContext = driverContextHandle
    let rawValue = JavaScriptCoreEngine.makeFunction(
      named: name,
      callback: callback,
      in: rawContext,
      functionClass: rawContext.functionClassRef
    )
    return JavaScriptCoreEngine.valueHandle(from: rawValue)
  }

  public func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback
  ) -> JSValue {
    JSValue(handleValue: makeFunctionHandle(named: name, callback: callback))
  }

  public func installGlobalFunction(
    named name: String,
    with attributes: JSPropertyAttributes = .none,
    callback: @escaping JSFunctionCallback
  ) {
    let function = makeFunction(named: name, callback: callback)
    withGlobalObject { globalObject in
      _ = JavaScriptCoreEngine.setStringPropertyHandle(
        name,
        on: globalObject.valueHandle(),
        to: function.valueHandle(),
        in: driverContextHandle,
        attributes: attributes.hostMemberAttributes
      )
    }
  }
}
