import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

// MARK: - Facade thin aliases and surface factories (S12)

@Test func javaScriptCoreFacadeThinAliasesAndSurfaceFactoriesSmoke() {
  func acceptAutoDefinition(
    _ definition: SwiftJavaScript.JSEngineClassDefinition<
      JSCContext,
      SwiftJavaScript.JSClassParentDescriptor<JSCContext, JSPropertyNameAccumulatorRef>,
      JSPropertyNameAccumulatorRef
    >
  ) -> String? {
    definition.className
  }

  var definition = JSCAutoClassDefinition()
  definition.className = "FacadeAlias"
  #expect(acceptAutoDefinition(definition) == "FacadeAlias")

  let staticValue = JSCStaticValue(
    name: "value",
    attributes: .readOnly,
    getProperty: { context, _ in .value(JSCValue(number: 1, in: context)) },
    setProperty: { context, _, _ in .value(JSCValue(undefinedIn: context)) }
  )
  #expect(staticValue.name == "value")

  let staticFunction = JSCStaticFunction(
    name: "fn",
    attributes: .none,
    callAsFunction: { context, _, _ in .value(JSCValue(undefinedIn: context)) }
  )
  #expect(staticFunction.name == "fn")

  let runtime = JSContextGroupCreate()!
  guard
    let contextHandle = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }
  do {
    let context = JSCInstantContext(contextRef: contextHandle)
    let identity = ObjectIdentifier(JSCAutoClassDefinition.self)
    let madeClass = context.makeClass(definition: definition, identity: identity)
    let cachedClass: JSCClass = context.makeClass(definition: definition, identity: identity)
    #expect(madeClass == cachedClass)
  }

  let undefinedValue = JSValueMakeUndefined(contextHandle)!
  let madeValue: JSCValue = JSCValue(
    ref: undefinedValue,
    contextRef: contextHandle
  )
  #expect(madeValue.type() == .undefined)

  JSGlobalContextRelease(contextHandle)
  JSContextGroupRelease(runtime)
}

// MARK: - Surface context/VM smoke (S8)

@Test func javaScriptCoreSurfaceContextAndVirtualMachineSmoke() async {
  let virtualMachine = await JSCVirtualMachine(.nonblocking)
  let context = await JSCContext(virtualMachine: virtualMachine, .nonblocking)
  let sibling = await JSCContext(virtualMachine: virtualMachine, .nonblocking)

  #expect(context.virtualMachine == virtualMachine)
  #expect(context.contextRef == context.contextRef)
  #expect(context.contextRef != sibling.contextRef)
  #expect(context.contextDataStorageBox() != nil)

  let sum = await context.withInstantContext { scope in
    scope.makeNumber(20).toNumber() + scope.makeNumber(22).toNumber()
  }
  #expect(sum == 42)

  let evaluated = await context.withInstantContext { scope in
    let result = scope.evaluateScript("6 * 7")
    switch consume result {
    case .value(let value):
      return value.toNumber()
    case .exception:
      return -1
    }
  }
  #expect(evaluated == 42)
}

// MARK: - makeFunction inside a raw callback (S8 regression)
//
// A function register built from inside an engine callback holds a *borrowing*
// context handle (`JSGlobalContextRef(borrowing:)`), so `surfaceFunctionClassRef` has to
// resolve the owning context through the data box. Before S8 that lookup comprehended only the legacy actor; the concrete `JSCContext` is now the owner, and
// this test is the crash regression for the whole fallback path.

@Test func javaScriptCoreMakeFunctionInsideCallbackDoesNotCrash() async {
  let context = await JSCContext(.nonblocking)

  let result = await context.withInstantContext { scope in
    scope.installGlobalFunction(named: "outer") { callbackContext, _, _ in
      let factoryMade = callbackContext.makeFunction(named: "factoryMade") {
        innerContext, _, _ in
        innerContext.return(innerContext.makeNumber(7))
      }
      let initializerMade = JSCValue(
        name: "initializerMade",
        callback: { innerContext, _, _ in
          innerContext.return(innerContext.makeNumber(35))
        },
        in: callbackContext
      )

      let factoryCall = factoryMade.call(arguments: [], in: callbackContext)
      let factoryResult: Double
      switch consume factoryCall {
      case .value(let value):
        factoryResult = value.toNumber()
      case .exception:
        return callbackContext.throw(callbackContext.makeString("factory call failed"))
      }

      let initializerCall = initializerMade.call(arguments: [], in: callbackContext)
      let initializerResult: Double
      switch consume initializerCall {
      case .value(let value):
        initializerResult = value.toNumber()
      case .exception:
        return callbackContext.throw(callbackContext.makeString("initializer call failed"))
      }

      return callbackContext.return(
        callbackContext.makeNumber(factoryResult + initializerResult)
      )
    }

    let evaluated = scope.evaluateScript("outer()")
    switch consume evaluated {
    case .value(let value):
      return value.toNumber()
    case .exception:
      return -1
    }
  }

  #expect(result == 42)
}

// MARK: - Borrowing-context owner lookup is nil-safe (S8)
//
// A raw context with no host-installed box must report `nil` from both owner
// lookups instead of trapping. The owning handle carries its own class refs,
// so the owning path needs no fallback at all.

@Test func javaScriptCoreContextBorrowReturnsNilWithoutBoundOwner() {
  let runtimeHandle = JSContextGroupCreate()!
  guard
    let contextHandle = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtimeHandle)
  else {
    Issue.record("expected runtime handle to create context handle")
    return
  }

  #expect(JSCContext.borrow(ctx: contextHandle) == nil)
  #expect(javaScriptCoreSurfaceFunctionClass(for: contextHandle) != nil)

  JSGlobalContextRelease(contextHandle)
  JSContextGroupRelease(runtimeHandle)
}
