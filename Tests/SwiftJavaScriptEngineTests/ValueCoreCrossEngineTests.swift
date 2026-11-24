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

private func adopt<C: JSContext>(
  _ contextType: C.Type,
  _ handle: consuming C.OwnedValueHandle?,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  switch consume handle {
  case .some(let owned):
    return scope.adoptCreatedHandle(owned)
  case .none:
    preconditionFailure("engine value factory returned nil")
  }
}

private func adoptObject<C: JSContext>(
  _ contextType: C.Type,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  let context = scope.driverContextHandle
  guard let result = context.makeObjectResultHandle() else {
    preconditionFailure("engine object factory returned nil")
  }
  switch consume result {
  case .value(let owned):
    return scope.adoptCreatedHandle(owned)
  case .exception(let owned):
    context.releaseCreatedHandle(owned)
    preconditionFailure("engine object factory returned an exception")
  }
}

private func adoptEvaluated<C: JSContext>(
  _ contextType: C.Type,
  _ source: String,
  in scope: borrowing C.InstantContext
) -> C.Value {
  _ = contextType
  let context = scope.driverContextHandle
  guard let script = context.makePreparedScriptHandle(source),
    let result = context.evaluatePreparedScriptResultHandle(
      script,
      sourceURL: nil,
      startingLineNumber: 1
    )
  else {
    preconditionFailure("engine could not evaluate \(source)")
  }
  switch consume result {
  case .value(let handle):
    return scope.adoptCreatedHandle(C.OwnedValueHandle.adopting(handle))
  case .exception(let handle):
    context.releaseCreatedHandle(C.OwnedValueHandle.adopting(handle))
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
  let context = scope.driverContextHandle
  var observation = ValueCoreObservation()

  let undefined: C.Value = adopt(contextType, context.makeUndefinedValueHandle(), in: scope)
  let null: C.Value = adopt(contextType, context.makeNullValueHandle(), in: scope)
  let trueValue: C.Value = adopt(contextType, context.makeBooleanValueHandle(true), in: scope)
  let falseValue: C.Value = adopt(contextType, context.makeBooleanValueHandle(false), in: scope)
  let number: C.Value = adopt(contextType, context.makeNumberValueHandle(42.5), in: scope)
  let zero: C.Value = adopt(contextType, context.makeNumberValueHandle(0), in: scope)
  let nan: C.Value = adopt(contextType, context.makeNumberValueHandle(.nan), in: scope)
  let nanAgain: C.Value = adopt(contextType, context.makeNumberValueHandle(.nan), in: scope)
  let string: C.Value = adopt(contextType, context.makeStringValueHandle("hello"), in: scope)
  let emptyString: C.Value = adopt(contextType, context.makeStringValueHandle(""), in: scope)
  let symbol: C.Value = adopt(contextType, context.makeSymbolValueHandle("surface"), in: scope)
  let bigInt: C.Value = adoptEvaluated(contextType, "1n", in: scope)
  let object: C.Value = adoptObject(contextType, in: scope)
  let otherObject: C.Value = adoptObject(contextType, in: scope)

  let anchoredNumber: C.Value = scope.anchorBorrowedHandle(number.borrowHandle())
  let anchoredObject: C.Value = scope.anchorBorrowedHandle(object.borrowHandle())

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

private func observeJSCValueCore() -> ValueCoreObservation {
  let runtime = JSCEngine.makeRuntimeHandle()
  guard let context = JSCEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
    preconditionFailure("JSCEngine could not create a context handle")
  }
  let observation: ValueCoreObservation
  do {
    let scope = JSCInstantContext(handle: context)
    observation = observeValueCore(JSCContext.self, in: scope)
    // Keep the arena alive until every observation above has been read.
    _ = scope.driverContextHandle
  }
  _ = context.releaseReference()
  _ = runtime.releaseReference()
  return observation
}

private func observeQJSValueCore() -> ValueCoreObservation {
  let runtime = QJSEngine.makeRuntimeHandle()
  guard let context = QJSEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
    preconditionFailure("QJSEngine could not create a context handle")
  }
  let observation: ValueCoreObservation
  do {
    let scope = QJSInstantContext(handle: context)
    observation = observeValueCore(QJSContext.self, in: scope)
    // QuickJS frees arena-owned references at drain; the scope must die before
    // the context it belongs to.
    _ = scope.driverContextHandle
  }
  _ = context.releaseReference()
  _ = runtime.releaseReference()
  return observation
}

@Test func valueCoreSemanticsMatchAcrossEngines() {
  #expect(observeJSCValueCore() == observeQJSValueCore())
}
