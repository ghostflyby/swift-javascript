import Foundation
import JavaScriptCore
import SwiftJavaScript

public struct JavaScriptCoreStringHandle: JSStringManualReferenceCountedHandle, @unchecked Sendable
{
  public let ref: JSStringRef

  public init(ref: JSStringRef) {
    self.ref = ref
  }

  @discardableResult
  public func retainReference() -> Bool {
    JSStringRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JSStringRelease(ref)
    return true
  }
}

private let javaScriptCoreFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSInstantContext<JavaScriptCoreEngine>(ctx: ctx)
  let callback = Unmanaged<Box<JSFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(
    JSObjectGetPrivate(function)!
  ).takeUnretainedValue().value
  let functionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: function, ctx: context)
  let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObject, ctx: context)
  let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
  let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
  let result = withJavaScriptCoreArguments(argumentsPointer, count: Int(argumentCount)) { args in
    callback(context, functionValue, thisValue, args).toPrivateResult()
  }

  switch result {
  case .value(let value):
    return value
  case .exception(let error):
    exception?.pointee = error
    return JSValueMakeUndefined(ctx)
  }
}

private func makeJavaScriptCoreFunctionClassDefinition() -> JavaScriptCore.JSClassDefinition {
  var definition = JavaScriptCore.kJSClassDefinitionEmpty
  definition.callAsFunction = javaScriptCoreFunctionCallback
  definition.finalize = { function in
    guard let function, let privateData = JSObjectGetPrivate(function) else {
      return
    }
    let callback = Unmanaged<Box<JSFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

func withJavaScriptCoreArguments<R: ~Copyable>(
  _ pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSArguments<JavaScriptCoreEngine>) -> R
) -> R {
  var empty: JSValueRef? = nil
  return withUnsafePointer(to: &empty) { emptyPointer in
    let arguments = JSArguments<JavaScriptCoreEngine>(
      pointer: pointer ?? emptyPointer, count: count)
    return body(arguments)
  }
}

extension JSTypedArrayKind {
  fileprivate var javaScriptCoreType: JSTypedArrayType {
    switch self {
    case .int8Array:
      return kJSTypedArrayTypeInt8Array
    case .uint8Array:
      return kJSTypedArrayTypeUint8Array
    case .uint8ClampedArray:
      return kJSTypedArrayTypeUint8ClampedArray
    case .int16Array:
      return kJSTypedArrayTypeInt16Array
    case .uint16Array:
      return kJSTypedArrayTypeUint16Array
    case .int32Array:
      return kJSTypedArrayTypeInt32Array
    case .uint32Array:
      return kJSTypedArrayTypeUint32Array
    case .float32Array:
      return kJSTypedArrayTypeFloat32Array
    case .float64Array:
      return kJSTypedArrayTypeFloat64Array
    }
  }

  fileprivate init?(javaScriptCoreType: JSTypedArrayType) {
    switch javaScriptCoreType {
    case kJSTypedArrayTypeInt8Array:
      self = .int8Array
    case kJSTypedArrayTypeUint8Array:
      self = .uint8Array
    case kJSTypedArrayTypeUint8ClampedArray:
      self = .uint8ClampedArray
    case kJSTypedArrayTypeInt16Array:
      self = .int16Array
    case kJSTypedArrayTypeUint16Array:
      self = .uint16Array
    case kJSTypedArrayTypeInt32Array:
      self = .int32Array
    case kJSTypedArrayTypeUint32Array:
      self = .uint32Array
    case kJSTypedArrayTypeFloat32Array:
      self = .float32Array
    case kJSTypedArrayTypeFloat64Array:
      self = .float64Array
    default:
      return nil
    }
  }
}

private enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JavaScriptCoreValueHandle)
}

public enum JavaScriptCoreEngine: JSEngine {
  public typealias ValueHandle = JavaScriptCoreValueHandle
  public typealias Engine = JavaScriptCoreEngine
  public typealias RuntimeHandle = JavaScriptCoreRuntimeHandle
  public typealias ContextHandle = JavaScriptCoreContextHandle
  public typealias StringHandle = JavaScriptCoreStringHandle

  public static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  private static func resultHandle(
    from result: JSDriverResult<JavaScriptCoreValueHandle>
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
    switch result {
    case .value(let value):
      return .value(value)
    case .exception(let exception):
      return .exception(exception)
    }
  }

  public static func makeRuntimeHandle() -> JavaScriptCoreRuntimeHandle {
    JavaScriptCoreRuntimeHandle()
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: JavaScriptCoreRuntimeHandle
  ) -> JavaScriptCoreContextHandle? {
    JavaScriptCoreContextHandle(runtime: runtime)
  }

  public static func globalObjectValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let objectRef = JSContextGetGlobalObject(context.ref) else {
      return nil
    }
    return JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref)
  }

  public static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    let rawValue = makeFunction(
      named: name,
      callback: callback,
      in: context,
      functionClass: context.functionClassRef
    )

    return rawValue
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    return makeString(value, in: context)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    return JavaScriptCoreValueHandle(
      ref: JSValueMakeNumber(context.ref, value)!,
      contextRef: context.ref
    )
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    return withJSString(value) { stringHandle in
      JavaScriptCoreValueHandle(
        ref: JSValueMakeSymbol(context.ref, stringHandle)!,
        contextRef: context.ref
      )
    }
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    return JavaScriptCoreValueHandle(
      ref: JSValueMakeBoolean(context.ref, value)!,
      contextRef: context.ref
    )
  }

  public static func makeNullValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    return JavaScriptCoreValueHandle(
      ref: JSValueMakeNull(context.ref)!,
      contextRef: context.ref
    )
  }

  public static func makeUndefinedValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {

    return makeUndefined(in: context)
  }

  public static func makeObjectResultHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(from: makeObject(in: context))
  }

  public static func makeArrayResultHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(from: makeArray(in: context))
  }

  public static func evaluateScriptResultHandle(
    _ script: String,
    _ context: JavaScriptCoreContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(
      from: evaluateScript(
        script,
        in: context,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }

  public static func valueTypeForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> SwiftJavaScript.JSType? {
    guard
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return nil
    }
    return valueType(of: rawValueRef, in: context.ref)
  }

  public static func toBooleanForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    guard
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return false
    }
    return JSValueToBoolean(context.ref, rawValueRef)
  }

  public static func toNumberForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Double {
    guard
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return .nan
    }
    return JSValueToNumber(context.ref, rawValueRef, nil)
  }

  public static func toStringForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> String? {
    guard
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return nil
    }
    return toString(rawValueRef, in: context.ref)
  }

  public static func propertyNamesForHandle(
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> [String]? {

    return propertyNames(on: object, in: context)
  }

  public static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(from: getProperty(key, on: object, in: context))
  }

  public static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func isValueHandleCompatibleWithContext(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    guard
      let valueGroup = contextGroupRef(from: value),
      let contextGroup = contextGroupRef(from: context)
    else {
      return false
    }
    return valueGroup == contextGroup
  }

  public static func getValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(from: getProperty(key, on: object, in: context))
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(from: getProperty(at: index, on: object, in: context))
  }

  public static func setValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch setProperty(at: index, on: object, to: value, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {

    return hasProperty(key, on: object, in: context)
  }

  public static func hasValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {

    return hasProperty(key, on: object, in: context)
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch deleteProperty(key, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func deleteValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch deleteProperty(key, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func callFunctionHandle(
    _ function: JSValueHandle<JavaScriptCoreEngine>,
    this thisValue: JSValueHandle<JavaScriptCoreEngine>? = nil,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = [],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    let rawThisValue: JavaScriptCoreValueHandle? = thisValue
    let rawArguments = arguments
    return resultHandle(
      from: callFunction(
        function,
        this: rawThisValue,
        arguments: rawArguments,
        in: context
      )
    )
  }

  public static func constructHandle(
    _ constructor: JSValueHandle<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = [],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    let rawArguments = arguments
    return resultHandle(
      from: construct(constructor, arguments: rawArguments, in: context))
  }

  public static func toObjectHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {

    return resultHandle(from: toObject(value, in: context))
  }

  public static func isArrayHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {

    return JSValueIsArray(context.ref, value.ref)
  }

  public static func isDateHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {

    return JSValueIsDate(context.ref, value.ref)
  }

  public static func isInstanceOfHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    constructor: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {

    return isInstanceOf(value, constructor: constructor, in: context)
  }

  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: JavaScriptCoreContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard
      let objectRef = makeArrayBufferWithBytesNoCopy(
        in: context.ref,
        bytes: bytes,
        byteLength: byteLength,
        bytesDeallocator: bytesDeallocator,
        deallocatorContext: deallocatorContext
      )
    else {
      return nil
    }

    return JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref)
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch objectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return arrayBufferByteLength(of: objectRef, in: context.ref)
    }
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch objectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return arrayBufferBytesPtr(of: objectRef, in: context.ref)
    }
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard
      let objectRef = makeTypedArray(
        in: context.ref,
        type: kind.javaScriptCoreType,
        length: length
      )
    else {
      return nil
    }

    return JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref)
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JavaScriptCoreEngine>
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch objectRef(for: arrayBuffer, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeTypedArrayWithArrayBuffer(
          in: context.ref,
          type: kind.javaScriptCoreType,
          arrayBuffer: objectRef
        )
      else {
        return nil
      }

      return JavaScriptCoreValueHandle(ref: typedArrayRef, contextRef: context.ref)
    }
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JavaScriptCoreEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch objectRef(for: arrayBuffer, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeTypedArrayWithArrayBufferAndOffset(
          in: context.ref,
          type: kind.javaScriptCoreType,
          arrayBuffer: objectRef,
          byteOffset: byteOffset,
          length: length
        )
      else {
        return nil
      }

      return JavaScriptCoreValueHandle(ref: typedArrayRef, contextRef: context.ref)
    }
  }

  public static func typedArrayLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch objectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return typedArrayLength(of: objectRef, in: context.ref)
    }
  }

  public static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch objectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return typedArrayByteLength(of: objectRef, in: context.ref)
    }
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch objectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      return typedArrayByteOffset(of: objectRef, in: context.ref)
    }
  }

  public static func typedArrayBufferForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch objectRef(for: value, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard let bufferRef = typedArrayBuffer(of: objectRef, in: context.ref) else {
        return nil
      }

      return JavaScriptCoreValueHandle(ref: bufferRef, contextRef: context.ref)
    }
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch objectRef(for: value, in: context) {
    case .exception:
      return (nil, true)
    case .object(let objectRef):
      return typedArrayBytesPtr(of: objectRef, in: context.ref)
    }
  }

  public static func isArrayBufferHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    guard
      let valueRef = valueRef(from: value),
      let type = typedArrayType(of: valueRef, in: context.ref)
    else {
      return false
    }

    return type == kJSTypedArrayTypeArrayBuffer
  }

  public static func typedArrayKindForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSTypedArrayKind? {
    guard
      let valueRef = valueRef(from: value),
      let type = typedArrayType(of: valueRef, in: context.ref)
    else {
      return nil
    }

    return JSTypedArrayKind(javaScriptCoreType: type)
  }

  package static func makeFunctionClass() -> JSClassRef {
    var definition = makeJavaScriptCoreFunctionClassDefinition()
    return JSClassCreate(&definition)!
  }

  package static func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    functionClass: JSClassRef
  ) -> JavaScriptCoreValueHandle {
    let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
    guard let functionRef = JSObjectMake(context.ref, functionClass, callbackRef) else {
      let callback = Unmanaged<Box<JSFunctionCallback<JavaScriptCoreEngine>>>.fromOpaque(
        callbackRef
      )
      .takeRetainedValue()
      _ = callback.value
      return makeUndefined(in: context)
    }
    if !name.isEmpty {
      _ = setProperty(
        "name",
        on: JavaScriptCoreValueHandle(ref: functionRef, contextRef: context.ref),
        to: makeString(name, in: context),
        in: context,
        attributes: [.dontEnum, .readOnly]
      )
    }
    return JavaScriptCoreValueHandle(ref: functionRef, contextRef: context.ref)
  }

  package static func makeObject(
    of jsClass: JSClassRef,
    privateData: UnsafeMutableRawPointer?,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    guard let objectRef = JSObjectMake(context.ref, jsClass, privateData) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref))
  }

  package static func makeObjectResultHandle(
    of jsClass: JSClassRef,
    privateData: UnsafeMutableRawPointer?,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    switch makeObject(of: jsClass, privateData: privateData, in: context) {
    case .value(let value):
      return .value(value)
    case .exception(let exception):
      return .exception(exception)
    }
  }

  package static func privateData(
    from value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<UnsafeMutableRawPointer?>? {
    switch objectRef(for: value, in: context) {
    case .exception:
      return .exception(nil)
    case .object(let objectRef):
      return .value(JSObjectGetPrivate(objectRef))
    }
  }

  package static func valueRef(from handle: JSValueHandle<JavaScriptCoreEngine>)
    -> JSValueRef?
  {
    handle.ref
  }

  package static func retainedValueRef(from handle: JSValueHandle<JavaScriptCoreEngine>)
    -> JSValueRef?
  {
    JSValueProtect(handle.contextRef, handle.ref)
    return handle.ref
  }

  package static func contextGroupRef(
    from context: JavaScriptCoreContextHandle
  ) -> JSContextGroupRef? {
    JSContextGetGroup(context.ref)
  }

  package static func contextGroupRef(
    from value: JSValueHandle<JavaScriptCoreEngine>
  ) -> JSContextGroupRef? {
    JSContextGetGroup(value.contextRef)
  }

  package static func privateData(from object: JSObjectRef?) -> UnsafeMutableRawPointer? {
    guard let object else {
      return nil
    }
    return JSObjectGetPrivate(object)
  }

  package static func privateData(fromGlobalObjectIn context: JSContextRef)
    -> UnsafeMutableRawPointer?
  {
    privateData(from: JSContextGetGlobalObject(context))
  }

  package static func stringProperty(
    _ key: String,
    on object: JSObjectRef,
    in context: JavaScriptCoreContextHandle
  ) -> String? {
    switch getProperty(
      key,
      on: JavaScriptCoreValueHandle(ref: object, contextRef: context.ref),
      in: context
    ) {
    case .exception:
      return nil
    case .value(let value):
      return value.toString()
    }
  }

  package static func jsType(from rawType: JavaScriptCore.JSType) -> SwiftJavaScript.JSType {
    switch rawType {
    case kJSTypeUndefined:
      return .undefined
    case kJSTypeNull:
      return .null
    case kJSTypeBoolean:
      return .boolean
    case kJSTypeNumber:
      return .number
    case kJSTypeString:
      return .string
    case kJSTypeSymbol:
      return .symbol
    case kJSTypeObject:
      return .object
    case kJSTypeBigInt:
      return .bigInt
    default:
      fatalError("Unknown JSType raw value: \(rawType)")
    }
  }

  package static func valueType(of value: JSValueRef, in context: JSContextRef)
    -> SwiftJavaScript.JSType
  {
    jsType(from: JSValueGetType(context, value))
  }

  package static var propertyAttributeNoneRawValue: UInt32 {
    UInt32(kJSPropertyAttributeNone)
  }

  package static var propertyAttributeDontEnumRawValue: UInt32 {
    UInt32(kJSPropertyAttributeDontEnum)
  }

  package static var propertyAttributeReadOnlyRawValue: UInt32 {
    UInt32(kJSPropertyAttributeReadOnly)
  }

  package static var propertyAttributeDontDeleteRawValue: UInt32 {
    UInt32(kJSPropertyAttributeDontDelete)
  }

  public static func stringLength(_ stringHandle: JavaScriptCoreStringHandle) -> Int {
    JSStringGetLength(stringHandle.ref)
  }

  public static func stringCharacters(
    _ stringHandle: JavaScriptCoreStringHandle
  ) -> UnsafePointer<UInt16>? {
    JSStringGetCharactersPtr(stringHandle.ref)
  }

  public static func makeJSString(_ value: String) -> JavaScriptCoreStringHandle {
    JavaScriptCoreStringHandle(ref: JSStringCreateWithCFString(value as CFString))
  }

  public static func stringEquals(
    _ lhs: JavaScriptCoreStringHandle,
    _ rhs: JavaScriptCoreStringHandle
  ) -> Bool {
    JSStringIsEqual(lhs.ref, rhs.ref)
  }

  package static func makeArrayBufferWithBytesNoCopy(
    in context: JSGlobalContextRef,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: JSTypedArrayBytesDeallocator?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSObjectRef? {
    var exception: JSValueRef?
    let ref = JSObjectMakeArrayBufferWithBytesNoCopy(
      context,
      bytes,
      byteLength,
      bytesDeallocator,
      deallocatorContext,
      &exception
    )
    guard exception == nil else {
      return nil
    }
    return ref
  }

  package static func arrayBufferByteLength(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let length = JSObjectGetArrayBufferByteLength(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return length
  }

  package static func arrayBufferBytesPtr(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var exception: JSValueRef?
    let bytes = JSObjectGetArrayBufferBytesPtr(context, object, &exception)
    return (bytes, exception != nil)
  }

  package static func makeTypedArray(
    in context: JSGlobalContextRef,
    type: JSTypedArrayType,
    length: Int
  ) -> JSObjectRef? {
    var exception: JSValueRef?
    let ref = JSObjectMakeTypedArray(context, type, length, &exception)
    guard exception == nil else {
      return nil
    }
    return ref
  }

  package static func makeTypedArrayWithArrayBuffer(
    in context: JSGlobalContextRef,
    type: JSTypedArrayType,
    arrayBuffer: JSObjectRef
  ) -> JSObjectRef? {
    var exception: JSValueRef?
    let ref = JSObjectMakeTypedArrayWithArrayBuffer(context, type, arrayBuffer, &exception)
    guard exception == nil else {
      return nil
    }
    return ref
  }

  package static func makeTypedArrayWithArrayBufferAndOffset(
    in context: JSGlobalContextRef,
    type: JSTypedArrayType,
    arrayBuffer: JSObjectRef,
    byteOffset: Int,
    length: Int
  ) -> JSObjectRef? {
    var exception: JSValueRef?
    let ref = JSObjectMakeTypedArrayWithArrayBufferAndOffset(
      context,
      type,
      arrayBuffer,
      byteOffset,
      length,
      &exception
    )
    guard exception == nil else {
      return nil
    }
    return ref
  }

  package static func typedArrayLength(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let length = JSObjectGetTypedArrayLength(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return length
  }

  package static func typedArrayByteLength(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let length = JSObjectGetTypedArrayByteLength(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return length
  }

  package static func typedArrayByteOffset(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let offset = JSObjectGetTypedArrayByteOffset(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return offset
  }

  package static func typedArrayBuffer(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> JSObjectRef? {
    var exception: JSValueRef?
    let buffer = JSObjectGetTypedArrayBuffer(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return buffer
  }

  package static func typedArrayBytesPtr(
    of object: JSObjectRef,
    in context: JSContextRef
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var exception: JSValueRef?
    let bytes = JSObjectGetTypedArrayBytesPtr(context, object, &exception)
    return (bytes, exception != nil)
  }

  package static func typedArrayType(
    of value: JSValueRef,
    in context: JSContextRef
  ) -> JSTypedArrayType? {
    var exception: JSValueRef?
    let type = JSValueGetTypedArrayType(context, value, &exception)
    guard exception == nil else {
      return nil
    }
    return type
  }

  package static func toString(_ value: JSValueRef, in context: JSContextRef) -> String? {
    guard let stringHandle = JSValueToStringCopy(context, value, nil) else {
      return nil
    }
    defer { JSStringRelease(stringHandle) }
    return String(
      jsStringHandle: JavaScriptCoreStringHandle(ref: stringHandle),
      engine: JavaScriptCoreEngine.self
    )
  }

  static func withDynamicPropertyCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    propertyName: JSStringRef?,
    _ body: (
      SwiftJavaScript.JSClassDefinition<
        JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
      >, borrowing JSInstantContext<JavaScriptCoreEngine>,
      borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, String
    ) -> R
  ) -> R? {
    guard let ctx, let object,
      let definition = classDefinition(from: object),
      let propertyName = classPropertyName(propertyName)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, object)
    let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
    return body(definition, context, thisValue, propertyName)
  }

  static func withFunctionCallbackInput<R>(
    ctx: JSContextRef?,
    functionRef: JSObjectRef?,
    thisObjectRef: JSObjectRef?,
    _ body: (
      SwiftJavaScript.JSClassDefinition<
        JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
      >, borrowing JSInstantContext<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) -> R
  ) -> R? {
    guard let ctx, let functionRef, let thisObjectRef,
      let definition = classDefinition(from: thisObjectRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, thisObjectRef)
    var functionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      ref: functionRef, ctx: context)
    var thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObjectRef, ctx: context)
    return body(definition, context, &functionValue, &thisValue)
  }

  static func withConstructorCallbackInput<R>(
    ctx: JSContextRef?,
    constructorRef: JSObjectRef?,
    _ body: (
      SwiftJavaScript.JSClassDefinition<
        JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
      >, borrowing JSInstantContext<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) -> R
  ) -> R? {
    guard let ctx, let constructorRef,
      let definition = classDefinition(from: constructorRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, constructorRef)
    var constructorValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      ref: constructorRef, ctx: context)
    var thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
    return body(definition, context, &constructorValue, &thisValue)
  }

  static func withHasInstanceCallbackInput<R>(
    ctx: JSContextRef?,
    constructorRef: JSObjectRef?,
    possibleInstanceRef: JSObjectRef?,
    _ body: (
      SwiftJavaScript.JSClassDefinition<
        JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
      >, borrowing JSInstantContext<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) -> R
  ) -> R? {
    guard let ctx, let constructorRef, let possibleInstanceRef,
      let definition = classDefinition(from: constructorRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, constructorRef)
    var constructorValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      ref: constructorRef, ctx: context)
    var possibleInstanceValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      ref: possibleInstanceRef, ctx: context)
    return body(definition, context, &constructorValue, &possibleInstanceValue)
  }

  static func withConvertToTypeCallbackInput<R>(
    ctx: JSContextRef?,
    objectRef: JSObjectRef?,
    jsType: SwiftJavaScript.JSType,
    _ body: (
      SwiftJavaScript.JSClassDefinition<
        JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
      >,
      borrowing JSInstantContext<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      SwiftJavaScript.JSType,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) ->
      R
  ) -> R? {
    guard let ctx, let objectRef,
      let definition = classDefinition(from: objectRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, objectRef)
    var objectValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: objectRef, ctx: context)
    var exceptionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
    return body(definition, context, &objectValue, jsType, &exceptionValue)
  }

  static func withPropertyNamesCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    accumulator: JSPropertyNameAccumulatorRef?,
    _ body: (
      SwiftJavaScript.JSClassDefinition<
        JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
      >, borrowing JSInstantContext<JavaScriptCoreEngine>,
      inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
      JSPropertyNameAccumulatorRef
    ) -> R
  ) -> R? {
    guard let ctx, let object, let accumulator,
      let definition = classDefinition(from: object)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, object)
    var thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
    return body(definition, context, &thisValue, accumulator)
  }

  static func withStaticValueCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    propertyName: JSStringRef?,
    _ body: (
      SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
      borrowing JSInstantContext<JavaScriptCoreEngine>,
      borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    ) ->
      R
  ) -> R? {
    guard let ctx, let object,
      let definition = classDefinition(from: object),
      let propertyName = classPropertyName(propertyName)
    else {
      return nil
    }

    rememberClassObjectContext(ctx, object)
    guard
      let valueDefinition = definition.inheritedStaticValue(
        named: propertyName,
        resolvingParentDefinition: { classDefinition(for: $0.ref) }
      )
    else {
      return nil
    }

    let context = JSInstantContext<JavaScriptCoreEngine>(ctx: ctx)
    let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
    return body(valueDefinition, context, thisValue)
  }

  static func withStaticFunctionCallbackInput<R>(
    ctx: JSContextRef?,
    function: JSObjectRef?,
    thisObject: JSObjectRef?,
    _ body: (
      SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>,
      borrowing JSInstantContext<JavaScriptCoreEngine>,
      borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
    )
      -> R
  ) -> R? {
    guard let ctx, let function, let thisObject,
      let definition = classDefinition(from: thisObject)
    else {
      return nil
    }

    rememberClassObjectContext(ctx, thisObject)
    let context = makeRememberedClassCallbackContext(ctx, thisObject)
    let functionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: function, ctx: context)
    let functionName = functionValue.getProperty(
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("name"), in: context
    )
    .toString(in: context)
    guard
      let functionDefinition = definition.inheritedStaticFunction(
        named: functionName,
        resolvingParentDefinition: { classDefinition(for: $0.ref) }
      )
    else {
      return nil
    }

    let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObject, ctx: context)
    return body(functionDefinition, context, thisValue)
  }

  static func callbackReturnValue(
    _ result: borrowing JSResult<JSValueRef>,
    in ctx: JSContextRef?,
    exception: UnsafeMutablePointer<JSValueRef?>?
  ) -> JSValueRef? {
    switch result {
    case .value(let value):
      return value
    case .exception(let error):
      exception?.pointee = error
      return JSValueMakeUndefined(ctx)
    }
  }

  static func callbackSucceeded(
    exceptionValue: JSValueRef?,
    exception: UnsafeMutablePointer<JSValueRef?>?
  ) -> Bool {
    guard let exceptionValue else {
      return true
    }
    exception?.pointee = exceptionValue
    return false
  }

  static func constructorCallbackReturnValue(
    _ result: borrowing JSResult<JSValueRef>,
    in ctx: JSContextRef?,
    exception: UnsafeMutablePointer<JSValueRef?>?
  ) -> JSObjectRef? {
    switch result {
    case .value(let value):
      if JSValueIsObject(ctx, value) {
        return unsafeBitCast(value, to: JSObjectRef?.self)
      }
      return nil
    case .exception(let error):
      exception?.pointee = error
      return nil
    }
  }

  package static func evaluateScript(
    _ script: String,
    in context: JavaScriptCoreContextHandle,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    withJSString(script) { scriptRef in
      withOptionalJSString(sourceURL) { sourceURLRef in
        var exception: JSValueRef?
        let resultRef = JSEvaluateScript(
          context.ref,
          scriptRef,
          nil,
          sourceURLRef,
          startingLineNumber,
          &exception
        )

        if let exception {
          return .exception(JavaScriptCoreValueHandle(ref: exception, contextRef: context.ref))
        }

        if let resultRef {
          return .value(JavaScriptCoreValueHandle(ref: resultRef, contextRef: context.ref))
        }

        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func makeString(
    _ value: String,
    in context: JavaScriptCoreContextHandle
  ) -> JavaScriptCoreValueHandle {
    withJSString(value) { stringHandle in
      JavaScriptCoreValueHandle(
        ref: JSValueMakeString(context.ref, stringHandle)!, contextRef: context.ref)
    }
  }

  package static func makeUndefined(in context: JavaScriptCoreContextHandle)
    -> JavaScriptCoreValueHandle
  {
    JavaScriptCoreValueHandle(ref: JSValueMakeUndefined(context.ref)!, contextRef: context.ref)
  }

  package static func makeObject(in context: JavaScriptCoreContextHandle)
    -> JSDriverResult<JavaScriptCoreValueHandle>
  {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref))
  }

  package static func makeArray(in context: JavaScriptCoreContextHandle)
    -> JSDriverResult<JavaScriptCoreValueHandle>
  {
    var exception: JSValueRef?
    let objectRef = JSObjectMakeArray(context.ref, 0, nil, &exception)
    if let exception {
      return .exception(JavaScriptCoreValueHandle(ref: exception, contextRef: context.ref))
    }
    if let objectRef {
      return .value(JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref))
    }
    return .value(makeUndefined(in: context))
  }

  package static func propertyNames(
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> [String] {
    switch objectRef(for: object, in: context) {
    case .exception:
      return []
    case .object(let objectRef):
      let names = JSObjectCopyPropertyNames(context.ref, objectRef)
      defer { JSPropertyNameArrayRelease(names) }

      let count = JSPropertyNameArrayGetCount(names)
      var result: [String] = []
      result.reserveCapacity(Int(count))
      for index in 0..<count {
        guard let keyHandle = JSPropertyNameArrayGetNameAtIndex(names, index) else {
          continue
        }
        result.append(
          String(
            jsStringHandle: JavaScriptCoreStringHandle(ref: keyHandle),
            engine: JavaScriptCoreEngine.self
          ))
      }
      return result
    }
  }

  package static func getProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        let valueRef = JSObjectGetProperty(context.ref, objectRef, keyRef, &exception)
        if let exception {
          return .exception(JavaScriptCoreValueHandle(ref: exception, contextRef: context.ref))
        }
        if let valueRef {
          return .value(JavaScriptCoreValueHandle(ref: valueRef, contextRef: context.ref))
        }
        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func getProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetPropertyForKey(context.ref, objectRef, key.ref, &exception)
      return result(value: valueRef, exception: exception, in: context)
    }
  }

  package static func getProperty(
    at index: UInt32,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetPropertyAtIndex(context.ref, objectRef, index, &exception)
      return result(value: valueRef, exception: exception, in: context)
    }
  }

  package static func hasProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch objectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        JSObjectHasProperty(context.ref, objectRef, keyRef)
      }
    }
  }

  package static func hasProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch objectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      var exception: JSValueRef?
      let result = JSObjectHasPropertyForKey(context.ref, objectRef, key.ref, &exception)
      return exception == nil && result
    }
  }

  package static func deleteProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        JSObjectDeleteProperty(context.ref, objectRef, keyRef, &exception)
        if exception != nil {
          return .exception(())
        }
        return .value(())
      }
    }
  }

  package static func deleteProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectDeletePropertyForKey(context.ref, objectRef, key.ref, &exception)
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  package static func callFunction(
    _ function: JavaScriptCoreValueHandle,
    this thisValue: JavaScriptCoreValueHandle?,
    arguments: [JavaScriptCoreValueHandle],
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    switch objectRef(for: function, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let functionRef):
      let thisObjectRef: JSObjectRef?
      if let thisValue {
        switch objectRef(for: thisValue, in: context) {
        case .exception(let exception):
          return .exception(exception)
        case .object(let objectRef):
          thisObjectRef = objectRef
        }
      } else {
        thisObjectRef = nil
      }

      var exception: JSValueRef?
      let refs = arguments.map { Optional($0.ref) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsFunction(
          context.ref,
          functionRef,
          thisObjectRef,
          buffer.count,
          buffer.baseAddress,
          &exception
        )
      }
      return result(value: resultRef, exception: exception, in: context)
    }
  }

  package static func construct(
    _ constructor: JavaScriptCoreValueHandle,
    arguments: [JavaScriptCoreValueHandle],
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    switch objectRef(for: constructor, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let constructorRef):
      var exception: JSValueRef?
      let refs = arguments.map { Optional($0.ref) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsConstructor(
          context.ref,
          constructorRef,
          buffer.count,
          buffer.baseAddress,
          &exception
        )
      }
      return result(value: resultRef, exception: exception, in: context)
    }
  }

  package static func toObject(
    _ value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    switch objectRef(for: value, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return .value(JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref))
    }
  }

  package static func isInstanceOf(
    _ value: JavaScriptCoreValueHandle,
    constructor: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch objectRef(for: constructor, in: context) {
    case .exception:
      return false
    case .object(let constructorRef):
      var exception: JSValueRef?
      let result = JSValueIsInstanceOfConstructor(
        context.ref, value.ref, constructorRef, &exception)
      return exception == nil && result
    }
  }

  package static func setProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        JSObjectSetProperty(
          context.ref,
          objectRef,
          keyRef,
          value.ref,
          javaScriptCorePropertyAttributes(from: attributes),
          &exception
        )
        if exception != nil {
          return .exception(())
        }
        return .value(())
      }
    }
  }

  package static func setProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectSetPropertyForKey(
        context.ref,
        objectRef,
        key.ref,
        value.ref,
        javaScriptCorePropertyAttributes(from: attributes),
        &exception
      )
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  package static func setProperty(
    at index: UInt32,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectSetPropertyAtIndex(context.ref, objectRef, index, value.ref, &exception)
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  private static func objectRef(
    for value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JavaScriptCoreObjectLookup {
    var exception: JSValueRef?
    guard let objectRef = JSValueToObject(context.ref, value.ref, &exception) else {
      if let exception {
        return .exception(JavaScriptCoreValueHandle(ref: exception, contextRef: context.ref))
      }
      return .exception(makeUndefined(in: context))
    }
    return .object(objectRef)
  }

  private static func result(
    value resultRef: JSValueRef?,
    exception exceptionRef: JSValueRef?,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<JavaScriptCoreValueHandle> {
    if let exceptionRef {
      return .exception(JavaScriptCoreValueHandle(ref: exceptionRef, contextRef: context.ref))
    }
    if let resultRef {
      return .value(JavaScriptCoreValueHandle(ref: resultRef, contextRef: context.ref))
    }
    return .value(makeUndefined(in: context))
  }
}

func javaScriptCorePropertyAttributes(from attributes: JSHostMemberAttributes) -> UInt32 {
  var rawValue = UInt32(kJSPropertyAttributeNone)
  if attributes.contains(.readOnly) {
    rawValue |= UInt32(kJSPropertyAttributeReadOnly)
  }
  if attributes.contains(.dontEnum) {
    rawValue |= UInt32(kJSPropertyAttributeDontEnum)
  }
  if attributes.contains(.dontDelete) {
    rawValue |= UInt32(kJSPropertyAttributeDontDelete)
  }
  return rawValue
}

private func withJSString<R>(_ string: String, _ body: (JSStringRef) -> R) -> R {
  let stringHandle = JSStringCreateWithCFString(string as CFString)!
  defer { JSStringRelease(stringHandle) }
  return body(stringHandle)
}

private func withOptionalJSString<R>(_ string: String?, _ body: (JSStringRef?) -> R) -> R {
  guard let string else {
    return body(nil)
  }
  return withJSString(string, body)
}
