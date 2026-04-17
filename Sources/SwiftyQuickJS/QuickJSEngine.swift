import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
  typealias CQuickJSValue = CQuickJSStatic.JSValue
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
  typealias CQuickJSValue = CQuickJSDynamic.JSValue
#endif

public enum QuickJSEngine: JSEngine {
  public typealias RuntimeHandle = QuickJSRuntimeHandle
  public typealias ContextHandle = QuickJSContextHandle
  public typealias ValueHandle = QuickJSValueHandle
  public typealias ClassHandle = QuickJSClassHandle
  public typealias StringHandle = QuickJSStringHandle

  public static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: false,
    supportsESModules: true,
    supportsPromiseJobQueueControl: false
  )

  public static func makeRuntimeHandle() -> QuickJSRuntimeHandle {
    guard let runtime = JS_NewRuntime() else {
      preconditionFailure("QuickJS could not create runtime")
    }
    return QuickJSRuntimeHandle(ref: runtime)
  }

  public static func makeBorrowedContextHandleFromRuntime(in runtime: QuickJSRuntimeHandle)
    -> QuickJSContextHandle?
  {
    guard let context = JS_NewContext(runtime.ref) else {
      return nil
    }
    return QuickJSContextHandle(ref: context)
  }

  public static func globalObjectValueHandle(_ context: QuickJSContextHandle) -> QuickJSValueHandle?
  {
    let global = JS_GetGlobalObject(context.ref)
    defer { JS_FreeValue(context.ref, global) }
    return QuickJSValueHandle(ref: global, contextRef: context.ref)
  }

  public static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<QuickJSEngine>,
    in context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
    let callbackBox = Unmanaged.passRetained(QuickJSFunctionCallbackBox(callback: callback))
    let function = name.withCString {
      JS_NewCClosure(
        context.ref,
        quickJSFunctionCallback,
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
    return QuickJSValueHandle(ref: function, contextRef: context.ref)
  }

  public static func evaluateScriptResultHandle(
    _ script: String,
    _ context: QuickJSContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<QuickJSValueHandle>? {
    let fileName = sourceURL ?? "<eval>"
    let source = adjustedScriptSource(script, startingLineNumber: startingLineNumber)
    let result = source.withCString { sourcePointer in
      fileName.withCString { filePointer in
        JS_Eval(
          context.ref,
          sourcePointer,
          source.utf8.count,
          filePointer,
          Int32(JS_EVAL_TYPE_GLOBAL)
        )
      }
    }
    return resultHandle(for: result, in: context.ref)
  }

  public static func valueTypeForHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> JSType? {
    if JS_IsUndefined(value.ref) {
      return .undefined
    }
    if JS_IsNull(value.ref) {
      return .null
    }
    if JS_IsBool(value.ref) {
      return .boolean
    }
    if JS_IsBigInt(value.ref) {
      return .bigInt
    }
    if JS_IsNumber(value.ref) {
      return .number
    }
    if JS_IsString(value.ref) {
      return .string
    }
    if JS_IsSymbol(value.ref) {
      return .symbol
    }
    if JS_IsObject(value.ref) {
      return .object
    }
    return nil
  }

  public static func toBooleanForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    JS_ToBool(context.ref, value.ref) == 1
  }

  public static func toNumberForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Double {
    var result = 0.0
    let status = JS_ToFloat64(context.ref, &result, value.ref)
    return status == 0 ? result : .nan
  }

  public static func toStringForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> String? {
    quickJSString(value.ref, in: context.ref)
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
    let rawValue = value.withCString { JS_NewString(context.ref, $0) }
    return QuickJSValueHandle(ref: rawValue, contextRef: context.ref)
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
    let rawValue = value.withCString { JS_NewSymbol(context.ref, $0, false) }
    return QuickJSValueHandle(ref: rawValue, contextRef: context.ref)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
    QuickJSValueHandle(ref: JS_NewFloat64(context.ref, value), contextRef: context.ref)
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
    QuickJSValueHandle(ref: JS_NewBool(context.ref, value), contextRef: context.ref)
  }

  public static func makeNullValueHandle(_ context: QuickJSContextHandle) -> QuickJSValueHandle? {
    QuickJSValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_NULL)),
      contextRef: context.ref
    )
  }

  public static func makeUndefinedValueHandle(_ context: QuickJSContextHandle)
    -> QuickJSValueHandle?
  {
    QuickJSValueHandle(
      ref: quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED)),
      contextRef: context.ref
    )
  }

  public static func makeObjectResultHandle(
    _ context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    resultHandle(for: JS_NewObject(context.ref), in: context.ref)
  }

  public static func makeArrayResultHandle(
    _ context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    resultHandle(for: JS_NewArray(context.ref), in: context.ref)
  }

  public static func isValueHandleCompatibleWithContext(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    JS_GetRuntime(value.contextRef) == JS_GetRuntime(context.ref)
  }

  public static func propertyNamesForHandle(
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> [String]? {
    var propertyEnumPointer: UnsafeMutablePointer<JSPropertyEnum>?
    var propertyCount: UInt32 = 0
    let flags = Int32(JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY)
    guard
      JS_GetOwnPropertyNames(
        context.ref,
        &propertyEnumPointer,
        &propertyCount,
        object.ref,
        flags
      ) == 0
    else {
      return nil
    }
    guard let propertyEnumPointer else {
      return []
    }
    defer {
      JS_FreePropertyEnum(context.ref, propertyEnumPointer, propertyCount)
    }
    return (0..<Int(propertyCount)).compactMap { index in
      atomString(propertyEnumPointer[index].atom, in: context.ref)
    }
  }

  public static func getStringPropertyHandle(
    _ key: String,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    let result = key.withCString { JS_GetPropertyStr(context.ref, object.ref, $0) }
    return resultHandle(for: result, in: context.ref)
  }

  public static func setStringPropertyHandle(
    _ key: String,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    let result = key.withCString {
      JS_DefinePropertyValueStr(
        context.ref,
        object.ref,
        $0,
        value.ref,
        propertyFlags(for: attributes)
      )
    }
    return result == 1
  }

  public static func getValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return resultHandle(for: JS_GetProperty(context.ref, object.ref, atom), in: context.ref)
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    resultHandle(
      for: JS_GetPropertyUint32(context.ref, object.ref, index),
      in: context.ref
    )
  }

  public static func setValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle,
    attributes _: JSHostMemberAttributes
  ) -> Bool {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return false
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return JS_SetProperty(context.ref, object.ref, atom, value.ref) == 1
  }

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    return JS_SetPropertyUint32(context.ref, object.ref, index, value.ref) == 1
  }

  public static func hasStringPropertyHandle(
    _ key: String,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let atom = key.withCString { JS_NewAtom(context.ref, $0) }
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    let result = JS_HasProperty(context.ref, object.ref, atom)
    return result >= 0 ? result == 1 : nil
  }

  public static func hasValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    let result = JS_HasProperty(context.ref, object.ref, atom)
    return result >= 0 ? result == 1 : nil
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    let atom = key.withCString { JS_NewAtom(context.ref, $0) }
    guard atom != 0 else {
      return false
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return JS_DeleteProperty(context.ref, object.ref, atom, Int32(JS_PROP_THROW)) == 1
  }

  public static func deleteValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return false
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return JS_DeleteProperty(context.ref, object.ref, atom, Int32(JS_PROP_THROW)) == 1
  }

  public static func callFunctionHandle(
    _ function: QuickJSValueHandle,
    this thisValue: QuickJSValueHandle?,
    arguments: [QuickJSValueHandle],
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    var rawArguments = arguments.map(\.ref)
    let thisRawValue = thisValue?.ref ?? quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
    let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
      JS_Call(
        context.ref,
        function.ref,
        thisRawValue,
        Int32(buffer.count),
        buffer.baseAddress
      )
    }
    return resultHandle(for: result, in: context.ref)
  }

  public static func constructHandle(
    _ constructor: QuickJSValueHandle,
    arguments: [QuickJSValueHandle],
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    var rawArguments = arguments.map(\.ref)
    let result = rawArguments.withUnsafeMutableBufferPointer { buffer in
      JS_CallConstructor(context.ref, constructor.ref, Int32(buffer.count), buffer.baseAddress)
    }
    return resultHandle(for: result, in: context.ref)
  }

  public static func toObjectHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    resultHandle(for: JS_ToObject(context.ref, value.ref), in: context.ref)
  }

  public static func isArrayHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> Bool? {
    JS_IsArray(value.ref)
  }

  public static func isDateHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    guard JS_IsObject(value.ref) else {
      return false
    }
    let globalObject = JS_GetGlobalObject(context.ref)
    defer { JS_FreeValue(context.ref, globalObject) }
    let dateConstructor = JS_GetPropertyStr(context.ref, globalObject, "Date")
    defer { JS_FreeValue(context.ref, dateConstructor) }
    if JS_IsException(dateConstructor) {
      return nil
    }
    let result = JS_IsInstanceOf(context.ref, value.ref, dateConstructor)
    return result >= 0 ? result == 1 : nil
  }

  public static func isInstanceOfHandle(
    _ value: QuickJSValueHandle,
    constructor: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let result = JS_IsInstanceOf(context.ref, value.ref, constructor.ref)
    return result >= 0 ? result == 1 : nil
  }

  public static func looselyEqualsHandle(
    _ lhs: QuickJSValueHandle,
    _ rhs: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let result = JS_IsEqual(context.ref, lhs.ref, rhs.ref)
    return result >= 0 ? result == 1 : nil
  }

  public static func strictlyEqualsHandle(
    _ lhs: QuickJSValueHandle,
    _ rhs: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    JS_IsStrictEqual(context.ref, lhs.ref, rhs.ref)
  }

  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: QuickJSContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> QuickJSValueHandle? {
    let opaque: UnsafeMutableRawPointer? =
      if let bytesDeallocator {
        Unmanaged.passRetained(
          QuickJSArrayBufferDeallocatorBox(
            deallocator: bytesDeallocator,
            context: deallocatorContext
          )
        ).toOpaque()
      } else {
        nil
      }
    let value = JS_NewArrayBuffer(
      context.ref,
      bytes?.assumingMemoryBound(to: UInt8.self),
      byteLength,
      quickJSArrayBufferFree,
      opaque,
      false
    )
    return QuickJSValueHandle(ref: value, contextRef: context.ref)
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Int? {
    var size = 0
    guard JS_GetArrayBuffer(context.ref, &size, value.ref) != nil else {
      return nil
    }
    return size
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var size = 0
    let bytes = JS_GetArrayBuffer(context.ref, &size, value.ref)
    return (UnsafeMutableRawPointer(bytes), bytes == nil)
  }

  public static func makeTypedArrayHandle(
    in _: QuickJSContextHandle,
    kind _: JSTypedArrayKind,
    length _: Int
  ) -> QuickJSValueHandle? {
    nil
  }

  public static func makeTypedArrayHandle(
    in _: QuickJSContextHandle,
    kind _: JSTypedArrayKind,
    arrayBuffer _: QuickJSValueHandle
  ) -> QuickJSValueHandle? {
    nil
  }

  public static func makeTypedArrayHandle(
    in _: QuickJSContextHandle,
    kind _: JSTypedArrayKind,
    arrayBuffer _: QuickJSValueHandle,
    byteOffset _: Int,
    length _: Int
  ) -> QuickJSValueHandle? {
    nil
  }

  public static func typedArrayLengthForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Int? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context.ref, buffer)
    guard bytesPerElement > 0 else {
      return nil
    }
    return byteLength / bytesPerElement
  }

  public static func typedArrayByteLengthForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Int? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context.ref, buffer)
    return byteLength
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Int? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    JS_FreeValue(context.ref, buffer)
    return byteOffset
  }

  public static func typedArrayBufferForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> QuickJSValueHandle? {
    var byteOffset = 0
    var byteLength = 0
    var bytesPerElement = 0
    let buffer = JS_GetTypedArrayBuffer(
      context.ref,
      value.ref,
      &byteOffset,
      &byteLength,
      &bytesPerElement
    )
    guard !JS_IsException(buffer) else {
      return nil
    }
    return QuickJSValueHandle(ref: buffer, contextRef: context.ref)
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    guard let buffer = typedArrayBufferForHandle(value, in: context) else {
      return (nil, true)
    }
    return arrayBufferBytesPtrForHandle(buffer, in: context)
  }

  public static func isArrayBufferHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> Bool {
    JS_IsArrayBuffer(value.ref)
  }

  public static func typedArrayKindForHandle(
    _ value: QuickJSValueHandle,
    in _: QuickJSContextHandle
  ) -> JSTypedArrayKind? {
    switch JS_GetTypedArrayType(value.ref) {
    case 1:
      return .int8Array
    case 2:
      return .uint8Array
    case 0:
      return .uint8ClampedArray
    case 3:
      return .int16Array
    case 4:
      return .uint16Array
    case 5:
      return .int32Array
    case 6:
      return .uint32Array
    case 10:
      return .float32Array
    case 11:
      return .float64Array
    default:
      return nil
    }
  }

  public static func stringLength(_ stringHandle: QuickJSStringHandle) -> Int {
    stringHandle.length
  }

  public static func stringCharacters(_ stringHandle: QuickJSStringHandle) -> UnsafePointer<UInt16>?
  {
    stringHandle.characters
  }

  public static func makeJSString(_ value: String) -> QuickJSStringHandle {
    QuickJSStringHandle(value)
  }

  public static func stringEquals(_ lhs: QuickJSStringHandle, _ rhs: QuickJSStringHandle) -> Bool {
    lhs.length == rhs.length
      && UnsafeBufferPointer(start: lhs.characters, count: lhs.length).elementsEqual(
        UnsafeBufferPointer(start: rhs.characters, count: rhs.length))
  }
}

private func adjustedScriptSource(_ script: String, startingLineNumber: Int32) -> String {
  guard startingLineNumber > 1 else {
    return script
  }
  return String(repeating: "\n", count: Int(startingLineNumber - 1)) + script
}

private func resultHandle(
  for result: CQuickJSValue,
  in contextRef: OpaquePointer
) -> JSResult<QuickJSValueHandle> {
  if JS_IsException(result) {
    let exception = JS_GetException(contextRef)
    return .exception(QuickJSValueHandle(ref: exception, contextRef: contextRef))
  }
  return .value(QuickJSValueHandle(ref: result, contextRef: contextRef))
}

private func quickJSFunctionCallback(
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

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let callback = Unmanaged<QuickJSFunctionCallbackBox>.fromOpaque(opaque).takeUnretainedValue()
    .callback
  let thisValue = SwiftJavaScript.JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(
      ref: thisValueRef,
      contextRef: contextRef
    )
  )

  let result = withQuickJSArguments(arguments, count: Int(argumentCount), contextRef: contextRef) {
    callback(context, thisValue, $0)
  }

  switch consume result {
  case .value(let value):
    return value.valueHandle().ref
  case .exception(let error):
    return JS_Throw(contextRef, error.valueHandle().ref)
  }
}

private func quickJSFunctionCallbackFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<QuickJSFunctionCallbackBox>.fromOpaque(opaque).takeRetainedValue()
}

private func withQuickJSArguments<R: ~Copyable>(
  _ arguments: UnsafeMutablePointer<CQuickJSValue>?,
  count: Int,
  contextRef: OpaquePointer,
  _ body: (borrowing JSArguments<QuickJSEngine>) -> R
) -> R {
  let swiftArguments = JSArguments<QuickJSEngine>(count: count) { index, _ in
    guard index >= 0, index < count, let arguments else {
      return nil
    }
    return QuickJSValueHandle(
      ref: JS_DupValue(contextRef, arguments[index]),
      contextRef: contextRef
    )
  }
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

private func atomString(_ atom: JSAtom, in contextRef: OpaquePointer) -> String? {
  var length = 0
  guard let cString = JS_AtomToCStringLen(contextRef, &length, atom) else {
    return nil
  }
  defer { JS_FreeCString(contextRef, cString) }
  let bytes = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
  return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
}

private func propertyFlags(for attributes: JSHostMemberAttributes) -> Int32 {
  var flags = Int32(
    JS_PROP_HAS_VALUE | JS_PROP_HAS_CONFIGURABLE | JS_PROP_HAS_WRITABLE
      | JS_PROP_HAS_ENUMERABLE | JS_PROP_THROW)
  if !attributes.contains(.dontDelete) {
    flags |= Int32(JS_PROP_CONFIGURABLE)
  }
  if !attributes.contains(.readOnly) {
    flags |= Int32(JS_PROP_WRITABLE)
  }
  if !attributes.contains(.dontEnum) {
    flags |= Int32(JS_PROP_ENUMERABLE)
  }
  return flags
}

private func quickJSImmediateValue(tag: Int32, payload: Int32 = 0) -> CQuickJSValue {
  CQuickJSValue(u: JSValueUnion(int32: payload), tag: Int64(tag))
}

private func quickJSArrayBufferFree(
  _: OpaquePointer?,
  opaque: UnsafeMutableRawPointer?,
  ptr: UnsafeMutableRawPointer?
) {
  guard let opaque else {
    return
  }
  let box = Unmanaged<QuickJSArrayBufferDeallocatorBox>.fromOpaque(opaque).takeRetainedValue()
  box.deallocator(ptr, box.context)
}

extension JSVirtualMachine where E == QuickJSEngine {

  public func gc() {
    JS_RunGC(self.driverRuntimeHandle.ref)
  }
}
