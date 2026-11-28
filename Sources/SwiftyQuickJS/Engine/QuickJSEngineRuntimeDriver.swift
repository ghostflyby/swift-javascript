import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

private enum QuickJSFunctionCallbackStorage {
  case surface(JSFunctionCallback<QJSInstantContext>)
}

// MARK: - Runtime and context lifecycle

package func quickJSMakeRuntime() -> OpaquePointer {
  guard let runtime = JS_NewRuntime() else {
    preconditionFailure("QuickJS could not create runtime")
  }
  // QuickJS's default 1 MB stack budget can exceed the stack of the thread
  // an executor runs on (a dedicated thread has roughly 512 KB), which lets
  // real recursion overflow before the logical check fires. Keep the limit
  // below that: stack top is recorded at runtime creation on the VM
  // executor and refreshed only on thread hand-offs.
  JS_SetMaxStackSize(runtime, 256 * 1024)
  return runtime
}

/// The runtime a context belongs to. Engine work: the caller runs on the VM
/// thread.
package func quickJSRuntimeRef(for context: OpaquePointer) -> OpaquePointer {
  let runtime: OpaquePointer = JS_GetRuntime(context)
  return runtime
}

// MARK: - Context data box

package func quickJSContextDataStorageBox(in context: OpaquePointer)
  -> JSContextDataStorageBox?
{
  guard let opaque = JS_GetContextOpaque(context) else {
    return nil
  }
  return Unmanaged<JSContextDataStorageBox>.fromOpaque(opaque).takeUnretainedValue()
}

package func quickJSInstallContextDataStorageBox(
  _ storage: JSContextDataStorageBox?,
  in context: OpaquePointer
) {
  if let oldOpaque = JS_GetContextOpaque(context) {
    JS_SetContextOpaque(context, nil)
    _ = Unmanaged<JSContextDataStorageBox>.fromOpaque(oldOpaque).takeRetainedValue()
  }
  if let storage = storage {
    JS_SetContextOpaque(context, Unmanaged.passRetained(storage).toOpaque())
  }
}

// MARK: - Global object and functions

/// The global object as a borrowed identity: the context owns its global
/// object for its lifetime, so the duplicate is settled here and the raw
/// value is handed to a non-owning local view.
package func quickJSGlobalObjectValue(_ context: OpaquePointer) -> CQuickJSValue? {
  let global = JS_GetGlobalObject(context)
  defer { JS_FreeValue(context, global) }
  return global
}

package func quickJSMakeFunction(
  named name: String,
  callback: @escaping JSFunctionCallback<QJSInstantContext>,
  in context: OpaquePointer
) -> CQuickJSValue? {
  let callbackBox = Unmanaged.passRetained(
    Box(QuickJSFunctionCallbackStorage.surface(callback)))
  let function = name.withCString {
    JS_NewCClosure(
      context,
      quickJSSurfaceFunctionCallback,
      $0,
      quickJSFunctionCallbackFinalizer,
      0,
      0,
      callbackBox.toOpaque()
    )
  }
  if JS_IsException(function) {
    _ = callbackBox.takeRetainedValue()
    return nil
  }
  return function
}

// MARK: - Scripts

/// Evaluate `source` with the global eval type. A prepared script only
/// carries the source text and the context that compiled it, so the driver
/// takes the text directly.
package func quickJSEvaluateScript(
  _ source: String,
  sourceURL: String? = nil,
  startingLineNumber: Int32 = 1,
  in context: OpaquePointer
) -> JSResult<CQuickJSValue> {
  let fileName = sourceURL ?? "<eval>"
  let result = quickJSAdjustedSource(source, startingLineNumber: startingLineNumber)
    .withCCharPointer { sourcePointer, sourceCount in
      fileName.withCString { filePointer in
        JS_Eval(
          context,
          sourcePointer,
          sourceCount,
          filePointer,
          Int32(JS_EVAL_TYPE_GLOBAL)
        )
      }
    }
  return quickJSResult(for: result, in: context)
}

// MARK: - Value classification and conversion

package func quickJSValueType(_ value: CQuickJSValue) -> SwiftJavaScript.JSType? {
  switch Int(value.tag) {
  case JS_TAG_UNDEFINED:
    return .undefined
  case JS_TAG_NULL:
    return .null
  case JS_TAG_BOOL:
    return .boolean
  case JS_TAG_BIG_INT, JS_TAG_SHORT_BIG_INT:
    return .bigInt
  case JS_TAG_FLOAT64, JS_TAG_INT:
    return .number
  case JS_TAG_STRING:
    return .string
  case JS_TAG_SYMBOL:
    return .symbol
  case JS_TAG_OBJECT:
    return .object
  default:
    return nil
  }
}

package func quickJSToBoolean(
  _ value: CQuickJSValue,
  in context: OpaquePointer
) -> Bool {
  return JS_ToBool(context, value) == 1
}

package func quickJSToNumber(
  _ value: CQuickJSValue,
  in context: OpaquePointer
) -> Double {
  var result = 0.0
  let status = JS_ToFloat64(context, &result, value)
  return status == 0 ? result : .nan
}

package func quickJSToString(
  _ value: CQuickJSValue,
  in context: OpaquePointer
) -> String? {
  quickJSString(value, in: context)
}

// MARK: - Context-free immediate conversion
//
// These helpers are the conversion path for values created without a context.
// They return nil for tags whose conversion needs the engine (strings,
// objects, symbols and bigints); a context-free value never carries those
// tags.

package func quickJSImmediateToBoolean(_ value: CQuickJSValue) -> Bool? {
  switch Int(value.tag) {
  case JS_TAG_UNDEFINED, JS_TAG_NULL:
    return false
  case JS_TAG_BOOL, JS_TAG_INT:
    return value.u.int32 != 0
  case JS_TAG_FLOAT64:
    let number = value.u.float64
    return !number.isNaN && number != 0
  default:
    return nil
  }
}

package func quickJSImmediateToNumber(_ value: CQuickJSValue) -> Double? {
  switch Int(value.tag) {
  case JS_TAG_UNDEFINED:
    return .nan
  case JS_TAG_NULL:
    return 0
  case JS_TAG_BOOL, JS_TAG_INT:
    return Double(value.u.int32)
  case JS_TAG_FLOAT64:
    return value.u.float64
  default:
    return nil
  }
}

package func quickJSImmediateToString(_ value: CQuickJSValue) -> String? {
  switch Int(value.tag) {
  case JS_TAG_UNDEFINED:
    return "undefined"
  case JS_TAG_NULL:
    return "null"
  case JS_TAG_BOOL:
    return value.u.int32 != 0 ? "true" : "false"
  case JS_TAG_INT:
    return String(value.u.int32)
  case JS_TAG_FLOAT64:
    return quickJSNumberString(value.u.float64)
  default:
    return nil
  }
}

package func quickJSImmediateStrictlyEquals(
  _ lhs: CQuickJSValue,
  _ rhs: CQuickJSValue
) -> Bool? {
  let lhsTag = Int(lhs.tag)
  let rhsTag = Int(rhs.tag)
  guard quickJSIsImmediateTag(lhsTag), quickJSIsImmediateTag(rhsTag) else {
    return nil
  }
  switch lhsTag {
  case JS_TAG_UNDEFINED, JS_TAG_NULL:
    return lhsTag == rhsTag
  case JS_TAG_BOOL:
    return rhsTag == JS_TAG_BOOL && lhs.u.int32 == rhs.u.int32
  case JS_TAG_INT:
    if rhsTag == JS_TAG_INT {
      return lhs.u.int32 == rhs.u.int32
    }
    if rhsTag == JS_TAG_FLOAT64 {
      return Double(lhs.u.int32) == rhs.u.float64
    }
    return false
  case JS_TAG_FLOAT64:
    if rhsTag == JS_TAG_FLOAT64 {
      return lhs.u.float64 == rhs.u.float64
    }
    if rhsTag == JS_TAG_INT {
      return lhs.u.float64 == Double(rhs.u.int32)
    }
    return false
  default:
    return false
  }
}

package func quickJSImmediateLooselyEquals(
  _ lhs: CQuickJSValue,
  _ rhs: CQuickJSValue
) -> Bool? {
  let lhsTag = Int(lhs.tag)
  let rhsTag = Int(rhs.tag)
  guard quickJSIsImmediateTag(lhsTag), quickJSIsImmediateTag(rhsTag) else {
    return nil
  }
  if lhsTag == JS_TAG_NULL || lhsTag == JS_TAG_UNDEFINED {
    // `null == undefined`, `null == null` and `undefined == undefined` are
    // all true; neither is loosely equal to any other immediate.
    return rhsTag == JS_TAG_NULL || rhsTag == JS_TAG_UNDEFINED
  }
  if rhsTag == JS_TAG_NULL || rhsTag == JS_TAG_UNDEFINED {
    return false
  }
  if lhsTag == rhsTag {
    return quickJSImmediateStrictlyEquals(lhs, rhs)
  }
  // Different immediate tags other than null/undefined compare through their
  // numeric values (booleans become 0/1; int and float compare numerically).
  guard
    let lhsNumber = quickJSImmediateToNumber(lhs),
    let rhsNumber = quickJSImmediateToNumber(rhs)
  else {
    return false
  }
  return lhsNumber == rhsNumber
}

private func quickJSIsImmediateTag(_ tag: Int) -> Bool {
  tag == JS_TAG_INT || tag == JS_TAG_BOOL || tag == JS_TAG_NULL
    || tag == JS_TAG_UNDEFINED || tag == JS_TAG_FLOAT64
}

/// ECMAScript `Number::toString` for a finite double, used only for
/// context-free values; a context-bound value delegates to QuickJS.
private func quickJSNumberString(_ value: Double) -> String {
  if value.isNaN { return "NaN" }
  if value == 0 { return "0" }
  if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
  if value < 0 { return "-" + quickJSNumberString(-value) }

  let description = value.description
  var mantissa = description
  var exponent = 0
  if let exponentIndex = description.firstIndex(where: { $0 == "e" || $0 == "E" }) {
    mantissa = String(description[..<exponentIndex])
    exponent = Int(description[description.index(after: exponentIndex)...])!
  }

  var digits = ""
  var n = 0
  if let dotIndex = mantissa.firstIndex(of: ".") {
    let integerPart = mantissa[..<dotIndex]
    let fractionPart = mantissa[mantissa.index(after: dotIndex)...]
    if integerPart == "0" {
      var leadingZeros = 0
      var index = fractionPart.startIndex
      while index < fractionPart.endIndex && fractionPart[index] == "0" {
        leadingZeros += 1
        index = fractionPart.index(after: index)
      }
      digits = String(fractionPart[index...])
      n = -leadingZeros
    } else {
      digits = String(integerPart) + String(fractionPart)
      n = integerPart.count
    }
    if exponent != 0 {
      n = exponent + 1
    }
  } else {
    digits = mantissa
    n = description.count
    if exponent != 0 {
      n = exponent + 1
    }
  }

  while digits.count > 1 && digits.last == "0" {
    digits.removeLast()
  }
  let digitCount = digits.count
  if digitCount <= n && n <= 21 {
    return digits + String(repeating: "0", count: n - digitCount)
  }
  if 0 < n && n <= 21 {
    let splitIndex = digits.index(digits.startIndex, offsetBy: n)
    return String(digits[..<splitIndex]) + "." + String(digits[splitIndex...])
  }
  if -6 < n && n <= 0 {
    return "0." + String(repeating: "0", count: -n) + digits
  }
  let first = digits.first!
  let rest = digits.dropFirst()
  let scientificExponent = n - 1
  let exponentText =
    scientificExponent >= 0 ? "+\(scientificExponent)" : "\(scientificExponent)"
  return rest.isEmpty
    ? "\(first)e\(exponentText)"
    : "\(first).\(rest)e\(exponentText)"
}

// MARK: - Creation factories (one owned reference each)

package func quickJSMakeString(
  _ value: String,
  in context: OpaquePointer
) -> CQuickJSValue? {
  return value.withCString { JS_NewString(context, $0) }
}

package func quickJSMakeSymbol(
  _ value: String,
  in context: OpaquePointer
) -> CQuickJSValue? {
  return value.withCString { JS_NewSymbol(context, $0, false) }
}

/// A number is an immediate: no engine call and no allocation.
package func quickJSMakeNumber(_ value: Double) -> CQuickJSValue {
  CQuickJSValue(u: JSValueUnion(float64: value), tag: Int64(JS_TAG_FLOAT64))
}

/// An integer is an immediate; the tag follows `JS_NewInt64`: `INT` while the
/// value fits in 32 bits, `FLOAT64` otherwise.
package func quickJSMakeNumber(_ value: some BinaryInteger) -> CQuickJSValue {
  if let int32 = Int32(exactly: value) {
    return CQuickJSValue(u: JSValueUnion(int32: int32), tag: Int64(JS_TAG_INT))
  }
  return quickJSMakeNumber(Double(value))
}

package func quickJSMakeNumber(
  _ value: Double,
  in context: OpaquePointer
) -> CQuickJSValue? {
  _ = context
  return quickJSMakeNumber(value)
}

/// A boolean is an immediate: no engine call and no allocation.
package func quickJSMakeBoolean(_ value: Bool) -> CQuickJSValue {
  CQuickJSValue(u: .init(int32: Int32(value ? 1 : 0)), tag: Int64(JS_TAG_BOOL))
}

package func quickJSMakeBoolean(
  _ value: Bool,
  in context: OpaquePointer
) -> CQuickJSValue? {
  _ = context
  return quickJSMakeBoolean(value)
}

package func quickJSMakeNull() -> CQuickJSValue {
  quickJSImmediateValue(tag: Int32(JS_TAG_NULL))
}

package func quickJSMakeNull(in context: OpaquePointer) -> CQuickJSValue? {
  _ = context
  return quickJSMakeNull()
}

package func quickJSMakeUndefined() -> CQuickJSValue {
  quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
}

package func quickJSMakeUndefined(in context: OpaquePointer) -> CQuickJSValue? {
  _ = context
  return quickJSMakeUndefined()
}

package func quickJSMakeObjectResult(
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  return quickJSResult(for: JS_NewObject(context), in: context)
}

package func quickJSMakeArrayResult(
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  return quickJSResult(for: JS_NewArray(context), in: context)
}

private func quickJSAdjustedSource(
  _ source: String,
  startingLineNumber: Int32
) -> QuickJSEvaluatedScriptSource {
  guard startingLineNumber > 1 else {
    return .plain(source)
  }
  return .adjusted(
    prefix: String(repeating: "\n", count: Int(startingLineNumber - 1)),
    source: source
  )
}

private enum QuickJSEvaluatedScriptSource {
  case plain(String)
  case adjusted(prefix: String, source: String)

  func withCCharPointer<R>(_ body: (UnsafePointer<CChar>?, Int) -> R) -> R {
    switch self {
    case .plain(let source):
      return source.withCString { pointer in
        body(pointer, source.utf8.count)
      }
    case .adjusted(let prefix, let source):
      var source = prefix + source
      return source.withUTF8 { pointer in
        pointer.withMemoryRebound(to: CChar.self) { pointer in
          body(pointer.baseAddress, pointer.count)
        }
      }
    }
  }
}

// MARK: - Surface callback trampoline (S6)
//
// QuickJS takes ownership of a C callback's return value and of the value
// passed to JS_Throw. §7.2 decision: the handoff carries a borrowed handle
// whose reference is owned by a scope arena (persistent values by the
// context default scope), so the trampoline duplicates for every form —
// temporary, persistent, and exception alike. The arena settles its own
// reference at drain; the engine settles the duplicated one.

private func quickJSSurfaceFunctionCallback(
  contextRef: OpaquePointer?,
  thisValueRef: CQuickJSValue,
  argumentCount: Int32,
  arguments: UnsafeMutablePointer<CQuickJSValue>?,
  _: Int32,
  opaque: UnsafeMutableRawPointer?
) -> CQuickJSValue {
  guard let contextRef, let opaque else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let scope = QJSInstantContext(contextRef: contextRef)

  guard
    case .surface(let callback) = Unmanaged<Box<QuickJSFunctionCallbackStorage>>
      .fromOpaque(opaque).takeUnretainedValue().value
  else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let thisValue = QJSValue(value: thisValueRef, contextRef: contextRef)

  let result = quickJSWithArguments(
    arguments, count: Int(argumentCount)
  ) { args in
    callback(scope, thisValue, args)
  }

  if result.isException {
    return JS_Throw(contextRef, JS_DupValue(contextRef, result.value))
  }
  return JS_DupValue(contextRef, result.value)
}

private func quickJSFunctionCallbackFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<Box<QuickJSFunctionCallbackStorage>>.fromOpaque(opaque).takeRetainedValue()
}

private func quickJSWithArguments<R: ~Copyable>(
  _ arguments: UnsafeMutablePointer<CQuickJSValue>?,
  count: Int,
  _ body: (borrowing QJSCallbackArguments) -> R
) -> R {
  let swiftArguments = QJSCallbackArguments(
    count: count,
    borrowedValueAt: { index in
      guard index >= 0, index < count, let arguments else {
        return nil
      }
      return arguments[index]
    }
  )
  return body(swiftArguments)
}

private func quickJSString(_ value: CQuickJSValue, in contextRef: OpaquePointer) -> String? {
  var length = 0
  guard let cString = JS_ToCStringLen2(contextRef, &length, value, false) else {
    return nil
  }
  defer { JS_FreeCString(contextRef, cString) }
  let bytes = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
  return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
}
