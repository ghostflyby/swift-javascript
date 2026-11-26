import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

@testable import SwiftJavaScript

// MARK: - Cross-engine value-core consistency (S4)
//
// Both engines must agree on the *observable* JavaScript semantics the base
// `JSValue` surface exposes: classification, ToString/ToNumber/ToBoolean,
// loose/strict equality, and the construction round-trips. The harness is
// generic over the context, so neither branch can lean on an
// engine-specific shortcut without the two observations diverging.

private struct ValueCoreObservation: Equatable {
  var types: [JSType] = []
  var predicates: [[Bool]] = []
  var strings: [String] = []
  var numbers: [String] = []
  var booleans: [Bool] = []
  var loose: [Bool] = []
  var strict: [Bool] = []
}

/// NaN never compares equal, so number observations are normalized to text.
private func describe(_ number: Double) -> String {
  number.isNaN ? "nan" : String(number)
}

private func predicateRow<V: SwiftJavaScript.JSValue & ~Copyable>(
  _ value: borrowing V
) -> [Bool] {
  [
    value.isUndefined(),
    value.isNull(),
    value.isBoolean(),
    value.isNumber(),
    value.isString(),
    value.isSymbol(),
    value.isObject(),
    value.isBigInt(),
  ]
}

// The `_ contextType:` parameters below are the repository's workaround for
// the compiler's NoUsage diagnostic on `borrowing` parameters whose type is an
// associated type of the generic parameter.

/// Promote a window-created value into a view that the whole observation can
/// read (`persist` moves its reference to the context default scope).
private func promoted<C: JSContext>(
  _ contextType: C.Type,
  _ value: borrowing C.Value,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  return scope.persist(value)
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

/// Rooted at the context: the operations of `C.Value` are addressed in
/// `C.InstantContext`, which only the context can name.
private func observeValueCore<C: JSContext>(
  _ contextType: C.Type,
  in scope: borrowing C.InstantContext
) -> ValueCoreObservation {
  _ = contextType
  var observation = ValueCoreObservation()

  let undefined: C.Value = promoted(contextType, scope.makeUndefined(), in: scope)
  let null: C.Value = promoted(contextType, scope.makeNull(), in: scope)
  let trueValue: C.Value = promoted(contextType, scope.makeBoolean(true), in: scope)
  let falseValue: C.Value = promoted(contextType, scope.makeBoolean(false), in: scope)
  let number: C.Value = promoted(contextType, scope.makeNumber(42.5), in: scope)
  let zero: C.Value = promoted(contextType, scope.makeNumber(0), in: scope)
  let nan: C.Value = promoted(contextType, scope.makeNumber(.nan), in: scope)
  let nanAgain: C.Value = promoted(contextType, scope.makeNumber(.nan), in: scope)
  let string: C.Value = promoted(contextType, scope.makeString("hello"), in: scope)
  let emptyString: C.Value = promoted(contextType, scope.makeString(""), in: scope)
  let symbol: C.Value = promoted(contextType, scope.makeSymbol("surface"), in: scope)
  let bigInt: C.Value = adoptEvaluated(contextType, "1n", in: scope)
  let object: C.Value = adoptObject(contextType, in: scope)
  let otherObject: C.Value = adoptObject(contextType, in: scope)

  // Two independent views of the same values: the number comparison is a
  // plain value comparison, and the object view comes back from a global
  // round-trip (the only value-level way to obtain a second view of one JS
  // object without a persistent binding).
  let anchoredNumber: C.Value = promoted(contextType, scope.makeNumber(42.5), in: scope)
  scope.setGlobalProperty(object, forKey: "valueCoreProbe", with: .none)
  let anchoredObject: C.Value = scope.getGlobalProperty(forKey: "valueCoreProbe")
  scope.deleteGlobalProperty(forKey: "valueCoreProbe")

  record(undefined, into: &observation)
  record(null, into: &observation)
  record(trueValue, into: &observation)
  record(falseValue, into: &observation)
  record(number, into: &observation)
  record(zero, into: &observation)
  record(nan, into: &observation)
  record(string, into: &observation)
  record(emptyString, into: &observation)
  record(symbol, into: &observation, conversions: false)
  // BigInt ToString agrees, but ToNumber does not: JavaScriptCore coerces a
  // BigInt to 1 while QuickJS reports NaN (its ToFloat64 is a throwing
  // conversion). Classification/ToBoolean is the shared contract.
  record(bigInt, into: &observation, conversions: false)
  record(object, into: &observation, conversions: false)
  record(otherObject, into: &observation, conversions: false)

  observation.strict = [
    number.strictlyEquals(anchoredNumber),
    number.strictlyEquals(string),
    !number.strictlyEquals(zero),
    !nan.strictlyEquals(nanAgain),
    object.strictlyEquals(anchoredObject),
    !object.strictlyEquals(otherObject),
  ]
  observation.loose = [
    number.looselyEquals(string),
    !number.looselyEquals(zero),
    !nan.looselyEquals(nanAgain),
    object.looselyEquals(anchoredObject),
    !object.looselyEquals(otherObject),
  ]
  return observation
}

private func record<V: SwiftJavaScript.JSValue & ~Copyable>(
  _ value: borrowing V,
  into observation: inout ValueCoreObservation,
  conversions: Bool = true
) {
  observation.types.append(value.type())
  observation.predicates.append(predicateRow(value))
  observation.booleans.append(value.toBoolean())
  guard conversions else { return }
  observation.strings.append(value.toString())
  observation.numbers.append(describe(value.toNumber()))
}

// MARK: - Engine drivers

/// Run the whole observation inside one synchronous window of a real context
/// actor, so neither branch leans on an engine-specific handle path.
private func observeValueCore<C: JSContext>(_: C.Type) async -> ValueCoreObservation {
  let context = C(virtualMachine: C.VirtualMachine())
  return await context.withInstantContext { scope in
    observeValueCore(C.self, in: scope)
  }
}

@Test func valueCoreSemanticsMatchAcrossEngines() async {
  let javaScriptCore = await observeValueCore(JSCContext.self)
  let quickJS = await observeValueCore(QJSContext.self)
  #expect(javaScriptCore == quickJS)
}
