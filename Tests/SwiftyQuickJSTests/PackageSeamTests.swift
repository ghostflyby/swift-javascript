import SwiftJavaScript
import SwiftyQuickJS
import Testing

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

// MARK: - Package seam (cross-target)
//
// Same assertion as the JavaScriptCore target's copy: the package-level
// scope/VM seams compile and run from a sibling target. QuickJS is the
// reference-counted engine, so the tracked creation value is released by the
// arena drain instead of being a no-op.

@Test func packageSurfaceScopeSeamsAreCallableAcrossTargets() {
  let runtime = quickJSMakeRuntime()
  guard let context = JS_NewContext(runtime) else {
    Issue.record("QJSEngine could not create a context")
    return
  }

  // The engine's scope type is `package`-initializable, so the scope protocol
  // defaults (factories, persistence, callback exits, global reads, scripts)
  // are reachable from a sibling target through it. The window lives in its
  // own block: its deinit drains the arena before the context goes away.
  do {
    let scope = QJSInstantContext(contextRef: context)

    let stringText = scope.makeString("seam").toString()
    let numberValue = scope.makeNumber(3).toNumber()
    let symbolType = scope.makeSymbol("sym").type()
    #expect(stringText == "seam")
    #expect(numberValue == 3)
    #expect(symbolType == .symbol)

    let persistedTruth = scope.persist(scope.makeBoolean(true)).toBoolean()
    #expect(persistedTruth)

    let globalIsObject = scope.globalObjectValue().isObject()
    #expect(globalIsObject)

    let function = scope.makeFunction(named: "seamFunction") { callbackContext, _, _ in
      callbackContext.return(callbackContext.makeNumber(1))
    }
    let functionIsObject = function.isObject()
    #expect(functionIsObject)

    // Self-owning inputs retain the engine context; they must die before the
    // test's context and runtime references are released.
    do {
      let key = scope.makePropertyStringKey("seamKey")
      let fromKeyText = scope.makeString(from: key).toString()
      #expect(fromKeyText == "seamKey")

      let script = scope.prepareScript("2 + 2")
      let scriptResult = scope.evaluateScript(
        script,
        sourceURL: nil,
        startingLineNumber: 1
      )
      switch consume scriptResult {
      case .value(let value):
        let sum = value.toNumber()
        #expect(sum == 4)
      case .exception:
        Issue.record("package-script evaluation threw")
      }
    }

    let returnedIsException = scope.return(scope.makeString("ok")).isException
    let thrownIsException = scope.throw(scope.makeString("boom")).isException
    let undefinedReturnIsException = scope.returnUndefined().isException
    #expect(!returnedIsException)
    #expect(thrownIsException)
    #expect(!undefinedReturnIsException)

    let missingType = scope.getGlobalProperty(forKey: "seamMissing").type()
    let hasMissing = scope.hasGlobalProperty("seamMissing")
    #expect(missingType == .undefined)
    #expect(!hasMissing)
    scope.deleteGlobalProperty(forKey: "seamMissing")

    let objectResult = scope.makeObject()
    switch consume objectResult {
    case .value(let object):
      let objectResultType = object.type()
      #expect(objectResultType == .object)
    case .exception:
      Issue.record("package object factory returned an exception")
    }
  }

  JS_FreeContext(context)
  JS_FreeRuntime(runtime)
}

@Test func packageVMSeamsAreCallableAcrossTargets() async {
  let virtualMachine = await QJSVirtualMachine(.nonblocking)
  let context = await QJSContext(virtualMachine: virtualMachine, .nonblocking)

  _ = virtualMachine.unownedExecutor
  // Package-level actor seams: the data-box swap, the runtime bits, and the
  // collection hook.
  #expect(context.contextDataStorageBox() != nil)
  await context.installContextDataStorageBox(nil)
  _ = await virtualMachine.runtimeBits()
  await virtualMachine.gc()
}

@Test func quickJSClassDefinitionRemainsAThinAlias() {
  func acceptCoreDefinition(
    _ definition: JSEngineClassDefinition<
      QJSContext,
      JSClassParentDescriptor<QJSContext, Never>,
      Never
    >
  ) -> String? {
    definition.className
  }

  var definition = QJSClassDefinition()
  definition.className = "QuickJSSeamClass"
  #expect(acceptCoreDefinition(definition) == "QuickJSSeamClass")

  #expect(ObjectIdentifier(QJSClass.Context.self) == ObjectIdentifier(QJSContext.self))
}
