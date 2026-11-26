import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

@testable import SwiftJavaScript

// MARK: - Cross-engine property/object/invocation consistency (S5)
//
// The S5 surface (property read/write/remove/existence, names, call,
// construct, method invocation, object conversion, and the object predicates)
// is exercised through the generic `JSValue` surface, so both engines have to
// agree on the observable JavaScript semantics rather than on an
// engine-specific shortcut.

private struct ValueOperationsObservation: Equatable {
  var setSucceeded = false
  var hasProperty = false
  var hasMissingProperty = true
  var propertyText = ""
  var missingText = ""
  var propertyNames: [String] = []
  var hiddenSet = false
  var hiddenHas = false
  var hiddenEnumerates = true
  var deleted = false
  var hasAfterDelete = true
  var callText = ""
  var callWithThisText = ""
  var constructText = ""
  var methodText = ""
  var methodWithArgumentText = ""
  var isArray = false
  var objectIsArray = true
  var isDate = false
  var objectIsDate = true
  var isInstanceOf = false
  var isInstanceOfOtherConstructor = true
  var isArrayBuffer = false
  var isTypedArray = false
  var typedArrayIsArrayBuffer = true
  var objectIsObject = false
  var loose = false
  var strict = false
  var strictSame = false
}

// The `_ contextType:` parameters below are the repository's workaround for
// the compiler's NoUsage diagnostic on `borrowing` parameters whose type is an
// associated type of the generic parameter.

/// Promote a window-created value into a view that the whole observation can
/// read (`persist` moves its reference to the context default scope).
private func promoted<C: JSContext>(
  _ contextType: C.Type,
  _ value: borrowing C.CallbackValue,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  return scope.persist(value)
}

private func adoptEvaluated<C: JSContext>(
  _ contextType: C.Type,
  _ source: String,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  switch scope.evaluateScript(source) {
  case .value(let value):
    return value
  case .exception:
    preconditionFailure("engine evaluation of \(source) threw")
  }
}

private func adoptObject<C: JSContext>(
  _ contextType: C.Type,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  switch scope.makeObject() {
  case .value(let owned):
    return scope.persist(owned)
  case .exception:
    preconditionFailure("engine object factory returned an exception")
  }
}

/// Collapse a noncopyable result into a Copyable description before any
/// assertion reads it (`#expect` captures its subject).
private func describe<V: SwiftJavaScript.JSValue & ~Copyable>(
  _ result: consuming JSResult<V>
) -> String {
  switch consume result {
  case .value(let value):
    return value.toString()
  case .exception:
    return "<exception>"
  }
}

/// Rooted at the context: the operations of `C.Value` are addressed in
/// `C.InstantContext`, which only the context can name.
private func observeValueOperations<C: JSContext>(
  _ contextType: C.Type,
  in scope: borrowing C.InstantContext
) -> ValueOperationsObservation {
  _ = contextType
  var observation = ValueOperationsObservation()

  let object: C.Value = adoptObject(contextType, in: scope)
  let number: C.Value = promoted(contextType, scope.makeNumber(7), in: scope)
  let numberText: C.Value = promoted(contextType, scope.makeString("7"), in: scope)
  let text: C.Value = promoted(contextType, scope.makeString("seven"), in: scope)

  observation.setSucceeded = object.setProperty(
    "name",
    to: text,
    attributes: .none,
    in: scope
  )
  observation.hasProperty = object.hasProperty("name", in: scope)
  observation.hasMissingProperty = object.hasProperty("absent", in: scope)
  observation.propertyText = describe(object.getProperty("name", in: scope))
  observation.missingText = describe(object.getProperty("absent", in: scope))
  observation.propertyNames = object.propertyNames(in: scope)
  observation.deleted = object.deleteProperty("name", in: scope)
  observation.hasAfterDelete = object.hasProperty("name", in: scope)

  // `.dontEnum` must survive the write on both engines: the property exists
  // but does not show up in the enumerable own-name list.
  let hidden: C.Value = adoptObject(contextType, in: scope)
  let hiddenText: C.Value = promoted(contextType, scope.makeString("hidden"), in: scope)
  observation.hiddenSet = hidden.setProperty(
    "secret",
    to: hiddenText,
    attributes: .dontEnum,
    in: scope
  )
  observation.hiddenHas = hidden.hasProperty("secret", in: scope)
  observation.hiddenEnumerates = !hidden.propertyNames(in: scope).isEmpty

  let function: C.Value = adoptEvaluated(contextType, "(function () { return 42; })", in: scope)
  observation.callText = describe(function.call(arguments: [], in: scope))

  let thisFunction: C.Value = adoptEvaluated(
    contextType,
    "(function () { return this.name; })",
    in: scope
  )
  let receiver: C.Value = adoptObject(contextType, in: scope)
  _ = receiver.setProperty("name", to: text, attributes: .none, in: scope)
  observation.callWithThisText = describe(
    thisFunction.call(this: receiver, arguments: [], in: scope)
  )

  let constructor: C.Value = adoptEvaluated(
    contextType,
    "(function () { this.value = 11; })",
    in: scope
  )
  let instance: C.Value
  switch constructor.construct(arguments: [], in: scope) {
  case .value(let value):
    instance = value
  case .exception:
    preconditionFailure("construct threw")
  }
  observation.constructText = describe(instance.getProperty("value", in: scope))

  let methodObject: C.Value = adoptEvaluated(
    contextType,
    "({ value: 21, double: function () { return this.value * 2; }, plus: function (n) { return this.value + n; } })",
    in: scope
  )
  observation.methodText = describe(methodObject.invokeMethod("double", arguments: [], in: scope))
  let argument: C.Value = promoted(contextType, scope.makeNumber(21), in: scope)
  observation.methodWithArgumentText = describe(
    methodObject.invokeMethod("plus", arguments: [argument.asCallArgument()], in: scope)
  )

  let array: C.Value = adoptEvaluated(contextType, "[1, 2, 3]", in: scope)
  observation.isArray = array.isArray(in: scope)
  observation.objectIsArray = object.isArray(in: scope)
  let date: C.Value = adoptEvaluated(contextType, "new Date()", in: scope)
  observation.isDate = date.isDate(in: scope)
  observation.objectIsDate = object.isDate(in: scope)
  observation.isInstanceOf = instance.isInstanceOf(constructor, in: scope)
  observation.isInstanceOfOtherConstructor = instance.isInstanceOf(function, in: scope)
  let arrayBuffer: C.Value = adoptEvaluated(contextType, "new ArrayBuffer(8)", in: scope)
  observation.isArrayBuffer = arrayBuffer.isArrayBuffer(in: scope)
  let typedArray: C.Value = adoptEvaluated(contextType, "new Uint8Array(8)", in: scope)
  observation.isTypedArray = typedArray.isTypedArray(in: scope)
  observation.typedArrayIsArrayBuffer = typedArray.isArrayBuffer(in: scope)

  let boxed: C.Value
  switch number.toObject(in: scope) {
  case .value(let value):
    boxed = value
  case .exception:
    preconditionFailure("toObject threw")
  }
  observation.objectIsObject = boxed.isObject()

  observation.loose = number.looselyEquals(numberText)
  observation.strict = number.strictlyEquals(numberText)
  observation.strictSame = number.strictlyEquals(number)
  return observation
}

// MARK: - Engine drivers

/// Run the whole observation inside one synchronous window of a real context
/// actor, so neither branch leans on an engine-specific handle path.
private func observeValueOperations<C: JSContext>(_: C.Type) async -> ValueOperationsObservation {
  let context = C(virtualMachine: C.VirtualMachine())
  return await context.withInstantContext { scope in
    observeValueOperations(C.self, in: scope)
  }
}

@Test func valueOperationsMatchAcrossEngines() async {
  let javaScriptCore = await observeValueOperations(JSCContext.self)
  let quickJS = await observeValueOperations(QJSContext.self)
  #expect(javaScriptCore == quickJS)
  #expect(javaScriptCore.setSucceeded)
  #expect(javaScriptCore.hasProperty)
  #expect(!javaScriptCore.hasMissingProperty)
  #expect(javaScriptCore.propertyText == "seven")
  #expect(javaScriptCore.missingText == "undefined")
  #expect(javaScriptCore.propertyNames == ["name"])
  #expect(javaScriptCore.deleted)
  #expect(!javaScriptCore.hasAfterDelete)
  #expect(javaScriptCore.hiddenSet)
  #expect(javaScriptCore.hiddenHas)
  #expect(!javaScriptCore.hiddenEnumerates)
  #expect(javaScriptCore.callText == "42")
  #expect(javaScriptCore.callWithThisText == "seven")
  #expect(javaScriptCore.constructText == "11")
  #expect(javaScriptCore.methodText == "42")
  #expect(javaScriptCore.methodWithArgumentText == "42")
  #expect(javaScriptCore.isArray)
  #expect(!javaScriptCore.objectIsArray)
  #expect(javaScriptCore.isDate)
  #expect(!javaScriptCore.objectIsDate)
  #expect(javaScriptCore.isInstanceOf)
  #expect(!javaScriptCore.isInstanceOfOtherConstructor)
  #expect(javaScriptCore.isArrayBuffer)
  #expect(javaScriptCore.isTypedArray)
  #expect(!javaScriptCore.typedArrayIsArrayBuffer)
  #expect(javaScriptCore.objectIsObject)
  #expect(javaScriptCore.loose)
  #expect(!javaScriptCore.strict)
  #expect(javaScriptCore.strictSame)
}
