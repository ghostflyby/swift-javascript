import SwiftJavaScript
import SwiftyJavaScriptCore
import Testing

// MARK: - Package seam (cross-target)
//
// These tests live in a different target from `SwiftJavaScript` and call the
// package-level scope/VM seams directly. Compiling them is the assertion:
// the package surface is what the engine modules and sibling test targets
// consume.
//
// The handle layer is keyed on the context handle (`ScopeCore<JSCContextHandle>`,
// `ScopeStackRegistry<JSCContextHandle>`); value-level operations are the
// scope protocol defaults, reached through the engine's scope type.

@Test func packageScopeSeamsAreCallableAcrossTargets() {
  let runtime = JSCEngine.makeRuntimeHandle()
  guard let context = JSCEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
    Issue.record("JSCEngine could not create a context handle")
    return
  }

  let core = ScopeCore<JSCContextHandle, JSImplicitStackRoots>(handle: context)
  let frame: ScopeFrame<JSCContextHandle> = core.frame
  #expect(frame.driverContextHandle == context)
  #expect(core.driverContextHandle == context)

  let created = context.makeNumberValueHandle(1)!
  let borrowed = created.borrowed()
  frame.track(created)
  #expect(frame.contains(matching: { $0.borrowed() == borrowed }))

  ScopeStackRegistry<JSCContextHandle>.push(core, for: context)
  #expect(ScopeStackRegistry<JSCContextHandle>.top(of: context) === frame)
  #expect(ScopeStackRegistry<JSCContextHandle>.defaultFrame(for: context) === frame)
  #expect(ScopeStackRegistry<JSCContextHandle>.vmThread(for: context) == nil)

  let taken = frame.takeFirst(matching: { $0.borrowed() == borrowed })
  if let taken = consume taken {
    context.releaseCreatedHandle(taken)
  }

  let popped = ScopeStackRegistry<JSCContextHandle>.pop(for: context)
  #expect(popped === frame)
  core.drain()

  _ = context.releaseReference()
  _ = runtime.releaseReference()
}

@Test func packageSurfaceScopeSeamsAreCallableAcrossTargets() {
  let runtime = JSCEngine.makeRuntimeHandle()
  guard let context = JSCEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
    Issue.record("JSCEngine could not create a context handle")
    return
  }

  // The engine's scope type is `package`-initializable, so the scope protocol
  // defaults (factories, persistence, callback exits, global reads, scripts)
  // are reachable from a sibling target through it. The window lives in its
  // own block: its deinit drains the arena before the context goes away.
  do {
    let scope = JSCInstantContext(handle: context)

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

  _ = context.releaseReference()
  _ = runtime.releaseReference()
}

@Test func packageVMThreadSeamsAreCallableAcrossTargets() {
  let thread = VMThread()
  let owner = thread.owner
  _ = thread.executor
  _ = thread.unownedExecutor
  #expect(!thread.isIsolatingCurrentContext())

  let answer = thread.runAndWait { 42 }
  #expect(answer == 42)

  thread.scheduleOnVMThread {}
  thread.schedulePersistentCleanup {}
  thread.perform {}
  withExtendedLifetime(owner) {}
}
