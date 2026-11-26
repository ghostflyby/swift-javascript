import JavaScriptCore
import Testing

@testable import SwiftJavaScript
@testable import SwiftyJavaScriptCore

// MARK: - JavaScriptCore surface scopes (S7)
//
// The surface window/manual-scope contract: factories, `persist` across a
// window boundary, nested windows, callback exit (`return`/`throw`), global
// property access, script evaluation, function callbacks, and the encoder /
// Codable surface. Values are `~Copyable`, so every observation is reduced to
// a Copyable result before an assertion reads it.

private struct JSCScopePayload: Codable, Equatable {
  var name: String
  var count: Int
  var items: [Double]
  var nested: Nested

  struct Nested: Codable, Equatable {
    var flag: Bool
  }
}

private enum JSCScopeDataKey: JSContextDataKey {
  typealias Value = String
}

@Suite
struct JSCScopeSurfaceTests {
  private func makeContext() -> (JSCRuntimeHandle, JSCContextHandle) {
    let runtime = JSCEngine.makeRuntimeHandle()
    guard let context = JSCEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
      preconditionFailure("JSCEngine could not create a context handle")
    }
    return (runtime, context)
  }

  @Test
  func factoriesProduceExpectedPrimitives() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    let stringType = scope.makeString("hello").type()
    let numberType = scope.makeNumber(3.5).type()
    let booleanType = scope.makeBoolean(true).type()
    let nullType = scope.makeNull().type()
    let undefinedType = scope.makeUndefined().type()
    let symbolType = scope.makeSymbol("sym").type()

    #expect(stringType == .string)
    #expect(numberType == .number)
    #expect(booleanType == .boolean)
    #expect(nullType == .null)
    #expect(undefinedType == .undefined)
    #expect(symbolType == .symbol)

    let object = scope.makeObject()
    switch consume object {
    case .value(let object):
      let isObject = object.isObject()
      let persisted = scope.persist(object)
      let isArray = persisted.isArray(in: scope)
      #expect(isObject)
      #expect(!isArray)
    case .exception:
      Issue.record("makeObject returned an exception")
    }

    let array = scope.makeArray()
    switch consume array {
    case .value(let array):
      let persisted = scope.persist(array)
      let isArray = persisted.isArray(in: scope)
      #expect(isArray)
    case .exception:
      Issue.record("makeArray returned an exception")
    }
  }

  @Test
  func persistMovesValueIntoTheOuterScope() {
    let (runtime, context) = makeContext()
    _ = runtime

    var outer = JSCScope(handle: context)
    outer.open()

    let persistedHandle: JSCValueHandle
    let persistedContext: JSCContextHandle
    do {
      let inner = JSCInstantContext(handle: context)
      let persisted = inner.persist(inner.makeString("kept"))
      persistedHandle = persisted.borrowHandle()
      persistedContext = persisted.contextHandle
      let inside = persisted.toString()
      #expect(inside == "kept")
    }

    // The inner window drained; the outer scope's arena now owns the value.
    let revived = JSCValue(handle: persistedHandle, contextHandle: persistedContext)
    let text = revived.toString()
    #expect(text == "kept")
  }

  @Test
  func nestedWindowsKeepTheOuterArenaAlive() {
    let (runtime, context) = makeContext()
    _ = runtime

    var outer = JSCScope(handle: context)
    outer.open()

    do {
      let first = JSCInstantContext(handle: context)
      let outerValue = first.persist(first.makeNumber(1))
      #expect(outerValue.toNumber() == 1)

      do {
        let second = JSCInstantContext(handle: context)
        let innerValue = second.persist(second.makeNumber(2))
        #expect(innerValue.toNumber() == 2)
      }

      // The nested window drained; the outer value is untouched.
      let stillAlive = outerValue.toNumber()
      #expect(stillAlive == 1)
    }

    // The outer scope is still open and usable after both windows closed.
    let text = outer.makeString("after").toString()
    #expect(text == "after")
  }

  @Test
  func withInstantWindowUsesTheCallerForInstantAndANestedWindowForScope() {
    let (runtime, context) = makeContext()
    _ = runtime

    let window = JSCInstantContext(handle: context)
    let windowIsCaller = window.withInstantWindow { inner in
      inner.driverContextHandle == window.driverContextHandle
    }
    #expect(windowIsCaller)

    var scope = JSCScope(handle: context)
    scope.open()

    let (innerNumber, innerText) = scope.withInstantWindow { inner -> (Double, String) in
      let number = inner.makeNumber(9).toNumber()
      let promoted = inner.persist(inner.makeString("promoted"))
      return (number, promoted.toString())
    }
    #expect(innerNumber == 9)
    #expect(innerText == "promoted")

    // The nested window drained; the manual scope's own arena is still usable.
    let afterText = scope.makeString("after").toString()
    #expect(afterText == "after")
  }

  @Test
  func returnAndThrowCarryTheExpectedFlags() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    let returned = scope.return(scope.makeString("ok"))
    let returnedIsException = returned.isException
    let returnedHandle = returned.borrowHandle()
    #expect(!returnedIsException)
    #expect(JSCValue(handle: returnedHandle, contextHandle: context).toString() == "ok")

    let thrown = scope.throw(scope.makeString("boom"))
    let thrownIsException = thrown.isException
    let thrownHandle = thrown.borrowHandle()
    #expect(thrownIsException)
    #expect(JSCValue(handle: thrownHandle, contextHandle: context).toString() == "boom")

    let undefinedReturn = scope.returnUndefined()
    let undefinedReturnIsException = undefinedReturn.isException
    #expect(!undefinedReturnIsException)

    let undefinedThrow = scope.throwUndefined()
    let undefinedThrowIsException = undefinedThrow.isException
    #expect(undefinedThrowIsException)

    // Returning a promoted value uses the same carrier.
    let promoted = scope.return(scope.persist(scope.makeBoolean(true)))
    let promotedIsException = promoted.isException
    #expect(!promotedIsException)
  }

  @Test
  func globalPropertyReadWriteDelete() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)
    let answer: StaticString = "answer"

    scope.setGlobalProperty(scope.makeNumber(41), forKey: answer)
    let hasAnswer = scope.hasGlobalProperty(answer)
    let readBack = scope.getGlobalProperty(forKey: answer)
    let readNumber = readBack.toNumber()
    #expect(hasAnswer)
    #expect(readNumber == 41)

    // Encoder-based write goes through the surface witness.
    let label: StaticString = "label"
    scope.setGlobalProperty("surface" as String, forKey: label)
    let labelText = scope.getGlobalProperty(forKey: label).toString()
    #expect(labelText == "surface")

    scope.deleteGlobalProperty(forKey: answer)
    let hasAfterDelete = scope.hasGlobalProperty(answer)
    let missingText = scope.getGlobalProperty(forKey: answer).toString()
    #expect(!hasAfterDelete)
    #expect(missingText == "undefined")

    let globalObject = scope.globalObjectValue()
    let globalIsObject = globalObject.isObject()
    #expect(globalIsObject)
  }

  @Test
  func scriptEvaluationThroughPreparedAndSourceForms() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    let prepared = scope.prepareScript("6 * 7")
    let preparedResult = scope.evaluateScript(
      prepared,
      sourceURL: nil,
      startingLineNumber: 1
    )
    switch consume preparedResult {
    case .value(let value):
      let number = value.toNumber()
      #expect(number == 42)
    case .exception:
      Issue.record("prepared script evaluation threw")
    }

    let sourceResult = scope.evaluateScript("'a' + 'b'")
    switch consume sourceResult {
    case .value(let value):
      let text = value.toString()
      #expect(text == "ab")
    case .exception:
      Issue.record("source script evaluation threw")
    }
  }

  @Test
  func functionCallbackUsesTheSurfaceWindow() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    scope.installGlobalFunction(named: "double") { callbackContext, _, arguments in
      let value = arguments.withValue(at: 0, in: callbackContext) { argument in
        argument.toNumber()
      }
      return callbackContext.return(callbackContext.makeNumber(value * 2))
    }

    let result = scope.evaluateScript("double(21)")
    switch consume result {
    case .value(let value):
      let doubled = value.toNumber()
      #expect(doubled == 42)
    case .exception:
      Issue.record("installed surface function threw")
    }

    let made = scope.makeFunction(named: "five") { callbackContext, _, _ in
      callbackContext.return(callbackContext.makeNumber(5))
    }
    let callResult = made.call(arguments: [], in: scope)
    switch consume callResult {
    case .value(let value):
      let number = value.toNumber()
      #expect(number == 5)
    case .exception:
      Issue.record("makeFunction result was not callable")
    }
  }

  @Test
  func surfaceEncoderWitnessesProduceValues() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    let boolean = true.toSurfaceValue(in: scope)
    let string = "encoded".toSurfaceValue(in: scope)
    let double = Double(2.5).toSurfaceValue(in: scope)
    let int32 = Int32(7).toSurfaceValue(in: scope)
    let uint32 = UInt32(9).toSurfaceValue(in: scope)

    let booleanType = boolean.type()
    let stringText = string.toString()
    let doubleNumber = double.toNumber()
    let int32Number = int32.toNumber()
    let uint32Number = uint32.toNumber()
    #expect(booleanType == .boolean)
    #expect(stringText == "encoded")
    #expect(doubleNumber == 2.5)
    #expect(int32Number == 7)
    #expect(uint32Number == 9)
  }

  @Test
  func codableConverterTraversesSurfaceObjects() throws {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    let payload = JSCScopePayload(
      name: "surface",
      count: 3,
      items: [1.5, 2.5],
      nested: .init(flag: true)
    )
    let encoded = try JSCodableValueConverter<JSCScopePayload>.tryEncode(payload, in: scope)

    let name = encoded.getProperty("name", in: scope)
    switch consume name {
    case .value(let value):
      let text = value.toString()
      #expect(text == "surface")
    case .exception:
      Issue.record("encoded object lost its name property")
    }

    let nested = encoded.getProperty("nested", in: scope)
    switch consume nested {
    case .value(let value):
      let flag = value.getProperty("flag", in: scope)
      switch consume flag {
      case .value(let flagValue):
        let isTrue = flagValue.toBoolean()
        #expect(isTrue)
      case .exception:
        Issue.record("nested object lost its flag property")
      }
    case .exception:
      Issue.record("encoded object lost its nested property")
    }

    let decoded = try JSCodableValueConverter<JSCScopePayload>.tryDecode(encoded, in: scope)
    #expect(decoded == payload)
  }

  @Test
  func codableConverterRunsInsideManualScopeWindow() throws {
    let (runtime, context) = makeContext()
    _ = runtime

    var scope = JSCScope(handle: context)
    scope.open()

    let payload = JSCScopePayload(
      name: "manual",
      count: 5,
      items: [0.5, 1.5],
      nested: .init(flag: false)
    )

    let encodedHandle = try scope.withInstantWindow {
      window throws(JSValueConversionError) -> JSCValueHandle in
      let encoded = try JSCodableValueConverter<JSCScopePayload>.tryEncode(
        payload,
        in: window
      )
      return encoded.borrowHandle()
    }

    // `tryEncode` persists its object graph into the context default scope, so
    // the encoded object is still readable after the nested window drained.
    let persisted = JSCValue(handle: encodedHandle, contextHandle: context)
    let decoded = try scope.withInstantWindow {
      window throws(JSValueConversionError) -> JSCScopePayload in
      let name = persisted.getProperty("name", in: window)
      switch consume name {
      case .value(let value):
        #expect(value.toString() == "manual")
      case .exception:
        Issue.record("persisted object lost its name property")
      }
      return try JSCodableValueConverter<JSCScopePayload>.tryDecode(
        persisted,
        in: window
      )
    }
    #expect(decoded == payload)
  }

  @Test
  func simpleValueInitializersPersistIntoTheDefaultScope() {
    let (runtime, context) = makeContext()
    _ = runtime
    let scope = JSCInstantContext(handle: context)

    let string = JSCValue(string: "initial", in: scope)
    let number = JSCValue(number: 12, in: scope)
    let boolean = JSCValue(boolean: false, in: scope)
    let object = JSCValue(objectIn: scope)
    let array = JSCValue(arrayIn: scope)

    let stringText = string.toString()
    let numberValue = number.toNumber()
    let booleanType = boolean.type()
    let objectType = object.type()
    let arrayIsArray = array.isArray(in: scope)
    #expect(stringText == "initial")
    #expect(numberValue == 12)
    #expect(booleanType == .boolean)
    #expect(objectType == .object)
    #expect(arrayIsArray)
  }

  @Test
  func contextDataIsSharedWithTheWindow() {
    let (runtime, context) = makeContext()
    _ = runtime
    // A bare engine context has no host-installed storage box; install one to
    // exercise the scope's data pass-through.
    context.installContextDataStorageBox(JSContextDataStorageBox())
    let scope = JSCInstantContext(handle: context)

    scope.setData("shared", for: JSCScopeDataKey.self)
    let value = scope.data(for: JSCScopeDataKey.self)
    #expect(value == "shared")

    scope.setData(nil, for: JSCScopeDataKey.self)
    let cleared = scope.data(for: JSCScopeDataKey.self)
    #expect(cleared == nil)
  }

  // MARK: - Concrete seams moved out of the generic engine tests
  //
  // The public scope protocol no longer names the context handle, so the
  // assertions that need it live on the concrete engine here (and in
  // `QJSScopeSurfaceTests`).

  /// A synchronous window pushes its own arena frame and pops it on drain, so
  /// the default scope is the stack top again afterwards.
  @Test
  func instantWindowRestoresTheDefaultScopeFrame() async {
    let context = JSCContext()
    let defaultFrame = ScopeStackRegistry<JSCContextHandle>.top(
      of: context.driverContextHandle)

    await context.withInstantContext { scope in
      let windowTop = ScopeStackRegistry<JSCContextHandle>.top(
        of: context.driverContextHandle)
      #expect(windowTop !== defaultFrame)
      _ = scope.makeString("windowed")
    }

    // The window drained; the context default frame is back on top.
    let restored = ScopeStackRegistry<JSCContextHandle>.top(
      of: context.driverContextHandle)
    #expect(restored === defaultFrame)
  }

  /// The invalid-slice failure path is only reachable through the raw
  /// typed-array driver (the public initializer traps on rejection); the
  /// engine must stay usable afterwards.
  @Test
  func invalidTypedArraySliceLeavesTheEngineUsable() async {
    let context = JSCContext()
    await context.withInstantContext { scope in
      let buffer = JSCArrayBuffer(copying: [10, 20, 30, 40, 50, 60], in: scope)
      let rejected = scope.driverContextHandle.makeTypedArrayHandle(
        kind: .uint16Array,
        arrayBuffer: buffer.withValue { $0.borrowHandle() },
        byteOffset: 1,
        length: 1
      )
      #expect(rejected == nil)

      let postFailureEvaluation = scope.evaluateScript("21 + 21")
      switch consume postFailureEvaluation {
      case .value(let value):
        let sum = value.toNumber()
        #expect(sum == 42)
      case .exception:
        Issue.record("Expected typed array construction failure to leave evaluation usable")
      }
    }
  }

  /// A JavaScript string value used as a property key has no value-level
  /// surface, so its read/write/has/delete contract is asserted on the driver.
  @Test
  func valueKeyDriverReadsWritesHasAndDeletes() async {
    let context = JSCContext()
    await context.withInstantContext { scope in
      let object: JSCValue
      switch scope.makeObject() {
      case .value(let made):
        object = scope.persist(made)
      case .exception:
        Issue.record("makeObject returned an exception")
        return
      }

      let key = scope.persist(scope.makeString("valueKey"))
      let stored = scope.persist(scope.makeString("abc"))
      let contextHandle = scope.driverContextHandle

      let wrote = contextHandle.setValuePropertyHandle(
        key.borrowHandle(),
        on: object.borrowHandle(),
        to: stored.borrowHandle(),
        attributes: .none
      )
      let has =
        contextHandle.hasValuePropertyHandle(
          key.borrowHandle(), on: object.borrowHandle()) ?? false
      let readIsString: Bool
      if let result = contextHandle.getValuePropertyHandle(
        key.borrowHandle(), on: object.borrowHandle())
      {
        switch consume result {
        case .value(let handle):
          readIsString =
            scope.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)).isString()
        case .exception(let handle):
          _ = scope.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle))
          readIsString = false
        }
      } else {
        readIsString = false
      }
      let deleted = contextHandle.deleteValuePropertyHandle(
        key.borrowHandle(), on: object.borrowHandle())
      let hasAfterDelete =
        contextHandle.hasValuePropertyHandle(
          key.borrowHandle(), on: object.borrowHandle()) ?? true

      #expect(wrote)
      #expect(has)
      #expect(readIsString)
      #expect(deleted)
      #expect(!hasAfterDelete)
    }
  }

  /// `readOnly`/`dontEnum`/`dontDelete` on the value-key driver path, moved
  /// down from the generic property tests.
  @Test
  func valueKeyDriverRespectsPropertyAttributes() async {
    let context = JSCContext()
    await context.withInstantContext { scope in
      let object: JSCValue
      switch scope.makeObject() {
      case .value(let made):
        object = scope.persist(made)
      case .exception:
        Issue.record("makeObject returned an exception")
        return
      }

      let contextHandle = scope.driverContextHandle
      let lockedKey = scope.persist(scope.makeString("locked"))
      let seven = scope.persist(scope.makeNumber(7))
      let nine = scope.persist(scope.makeNumber(9))
      _ = contextHandle.setValuePropertyHandle(
        lockedKey.borrowHandle(),
        on: object.borrowHandle(),
        to: seven.borrowHandle(),
        attributes: .readOnly
      )
      _ = contextHandle.setValuePropertyHandle(
        lockedKey.borrowHandle(),
        on: object.borrowHandle(),
        to: nine.borrowHandle(),
        attributes: .none
      )

      let hiddenKey = scope.persist(scope.makeString("hidden"))
      let hiddenValue = scope.persist(scope.makeNumber(1))
      _ = contextHandle.setValuePropertyHandle(
        hiddenKey.borrowHandle(),
        on: object.borrowHandle(),
        to: hiddenValue.borrowHandle(),
        attributes: .dontEnum
      )

      let pinnedKey = scope.persist(scope.makeString("pinned"))
      let pinnedValue = scope.persist(scope.makeNumber(2))
      _ = contextHandle.setValuePropertyHandle(
        pinnedKey.borrowHandle(),
        on: object.borrowHandle(),
        to: pinnedValue.borrowHandle(),
        attributes: .dontDelete
      )

      let lockedNumber: Double?
      if let result = contextHandle.getValuePropertyHandle(
        lockedKey.borrowHandle(), on: object.borrowHandle())
      {
        switch consume result {
        case .value(let handle):
          lockedNumber =
            scope.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle)).toNumber()
        case .exception(let handle):
          _ = scope.adoptCreatedHandle(JSCOwnedValueHandle.adopting(handle))
          lockedNumber = nil
        }
      } else {
        lockedNumber = nil
      }

      scope.setGlobalProperty(object, forKey: "attributeObject", with: .none)
      let hiddenEnumerated = scope.evaluateScript(
        "Object.keys(attributeObject).includes('hidden')")
      let pinnedDeleted = scope.evaluateScript("delete attributeObject.pinned")
      let pinnedStillPresent = scope.evaluateScript("'pinned' in attributeObject")

      #expect(lockedNumber == 7)

      switch consume hiddenEnumerated {
      case .value(let value):
        let isEnumerated = value.toBoolean()
        #expect(!isEnumerated)
      case .exception:
        Issue.record("Expected Object.keys check for hidden value-key property")
      }

      switch consume pinnedDeleted {
      case .value(let value):
        let isDeleted = value.toBoolean()
        #expect(!isDeleted)
      case .exception:
        Issue.record("Expected delete check for pinned value-key property")
      }

      switch consume pinnedStillPresent {
      case .value(let value):
        let isPresent = value.toBoolean()
        #expect(isPresent)
      case .exception:
        Issue.record("Expected membership check for pinned value-key property")
      }
    }
  }
}
