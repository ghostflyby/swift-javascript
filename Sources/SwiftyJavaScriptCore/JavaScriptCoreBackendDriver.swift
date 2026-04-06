import Foundation
import JavaScriptCore
import SwiftJavaScript

public typealias JavaScriptCoreValueRef = JSValueRef
public typealias JavaScriptCoreObjectRef = JSObjectRef
public typealias JavaScriptCoreContextRef = JSContextRef
public typealias JavaScriptCoreGlobalContextRef = JSGlobalContextRef
public typealias JavaScriptCoreStringRef = JSStringRef
public typealias JavaScriptCoreClassRef = JSClassRef
public typealias JavaScriptCorePropertyNameAccumulatorRef = JSPropertyNameAccumulatorRef
public typealias JavaScriptCoreObjectInitializeCallback = JSObjectInitializeCallback
public typealias JavaScriptCoreObjectFinalizeCallback = JSObjectFinalizeCallback
public typealias JavaScriptCoreObjectGetPropertyCallback = JSObjectGetPropertyCallback
public typealias JavaScriptCoreObjectSetPropertyCallback = JSObjectSetPropertyCallback
public typealias JavaScriptCoreObjectHasPropertyCallback = JSObjectHasPropertyCallback
public typealias JavaScriptCoreObjectDeletePropertyCallback = JSObjectDeletePropertyCallback
public typealias JavaScriptCoreObjectGetPropertyNamesCallback = JSObjectGetPropertyNamesCallback
public typealias JavaScriptCoreObjectCallAsFunctionCallback = JSObjectCallAsFunctionCallback
public typealias JavaScriptCoreObjectCallAsConstructorCallback = JSObjectCallAsConstructorCallback
public typealias JavaScriptCoreObjectHasInstanceCallback = JSObjectHasInstanceCallback
public typealias JavaScriptCoreObjectConvertToTypeCallback = JSObjectConvertToTypeCallback
public typealias JavaScriptCoreClassDefinition = JavaScriptCore.JSClassDefinition
public typealias JavaScriptCoreStaticValue = JavaScriptCore.JSStaticValue
public typealias JavaScriptCoreStaticFunction = JavaScriptCore.JSStaticFunction
public typealias JavaScriptCoreTypedArrayType = JSTypedArrayType
public typealias JavaScriptCoreTypedArrayBytesDeallocator = JSTypedArrayBytesDeallocator

public struct JavaScriptCoreStringHandle: JSStringManualReferenceCountedHandle, @unchecked Sendable
{
  public let ref: JavaScriptCoreStringRef

  public init(ref: JavaScriptCoreStringRef) {
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

package typealias JavaScriptCoreRawRuntime = JavaScriptCoreRuntimeHandle
package typealias JavaScriptCoreRawContext = JavaScriptCoreContextHandle

package final class JavaScriptCoreRawValue: @unchecked Sendable {
  package let ref: JSValueRef
  package let contextRef: JavaScriptCoreGlobalContextRef

  package init(ref: JSValueRef, contextRef: JavaScriptCoreGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
    JSValueProtect(contextRef, ref)
  }

  deinit {
    JSValueUnprotect(contextRef, ref)
  }

  package var type: SwiftJavaScript.JSType {
    JavaScriptCoreEngine.valueType(of: ref, in: contextRef)
  }

  package func toDouble() -> Double {
    JSValueToNumber(contextRef, ref, nil)
  }

  package func toString() -> String? {
    guard let stringHandle = JSValueToStringCopy(contextRef, ref, nil) else {
      return nil
    }
    defer { JSStringRelease(stringHandle) }
    return String(
      jsStringHandle: JavaScriptCoreStringHandle(ref: stringHandle),
      engine: JavaScriptCoreEngine.self
    )
  }
}

private let javaScriptCoreFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSInstantContext(ctx: ctx)
  let callback = Unmanaged<Box<JSFunctionCallback>>.fromOpaque(
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
    let callback = Unmanaged<Box<JSFunctionCallback>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

private func withJavaScriptCoreArguments<R: ~Copyable>(
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

private enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JavaScriptCoreRawValue)
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

  package static func makeRuntime() -> JavaScriptCoreRawRuntime {
    JavaScriptCoreRuntimeHandle()
  }

  package static func makeContext(in runtime: JavaScriptCoreRawRuntime)
    -> JavaScriptCoreRawContext
  {
    JavaScriptCoreContextHandle(runtime: runtime)
  }

  private static func rawContext(
    from context: JavaScriptCoreContextHandle
  ) -> JavaScriptCoreRawContext? {
    context
  }

  private static func resultHandle(
    from result: JSDriverResult<JavaScriptCoreRawValue>
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
    switch result {
    case .value(let value):
      return .value(JSValueHandle<JavaScriptCoreEngine>(rawValue: value))
    case .exception(let exception):
      return .exception(JSValueHandle<JavaScriptCoreEngine>(rawValue: exception))
    }
  }

  public static func makeRuntimeHandle() -> JavaScriptCoreRuntimeHandle {
    makeRuntime()
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: JavaScriptCoreRuntimeHandle
  ) -> JavaScriptCoreContextHandle? {
    makeContext(in: runtime)
  }

  public static func globalObjectValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let objectRef = globalObject(in: context.ref) else {
      return nil
    }
    return valueHandle(from: objectRef, in: context)
  }

  public static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSEngineFunctionCallback<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }

    let rawValue = makeFunction(
      named: name,
      callback: callback,
      in: rawContext,
      functionClass: context.functionClassRef
    )

    return JSValueHandle<JavaScriptCoreEngine>(rawValue: rawValue)
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: makeString(value, in: rawContext))
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: makeNumber(value, in: rawContext))
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: makeSymbol(value, in: rawContext))
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: makeBoolean(value, in: rawContext))
  }

  public static func makeNullValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: makeNull(in: rawContext))
  }

  public static func makeUndefinedValueHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: makeUndefined(in: rawContext))
  }

  public static func makeObjectResultHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(from: makeObject(in: rawContext))
  }

  public static func makeArrayResultHandle(
    _ context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(from: makeArray(in: rawContext))
  }

  public static func evaluateScriptResultHandle(
    _ script: String,
    _ context: JavaScriptCoreContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(
      from: evaluateScript(
        script,
        in: rawContext,
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
      let rawContext = rawContext(from: context),
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return nil
    }
    return valueType(of: rawValueRef, in: rawContext.ref)
  }

  public static func toBooleanForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    guard
      let rawContext = rawContext(from: context),
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return false
    }
    return toBoolean(rawValueRef, in: rawContext.ref)
  }

  public static func toNumberForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Double {
    guard
      let rawContext = rawContext(from: context),
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return .nan
    }
    return toNumber(rawValueRef, in: rawContext.ref)
  }

  public static func toStringForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> String? {
    guard
      let rawContext = rawContext(from: context),
      let rawValueRef = JavaScriptCoreEngine.valueRef(from: value)
    else {
      return nil
    }
    return toString(rawValueRef, in: rawContext.ref)
  }

  public static func propertyNamesForHandle(
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> [String]? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return propertyNames(on: object.rawValue, in: rawContext)
  }

  public static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(from: getProperty(key, on: object.rawValue, in: rawContext))
  }

  public static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawContext = rawContext(from: context) else {
      return false
    }
    switch setProperty(
      key,
      on: object.rawValue,
      to: value.rawValue,
      in: rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func getValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(from: getProperty(key.rawValue, on: object.rawValue, in: rawContext))
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(from: getProperty(at: index, on: object.rawValue, in: rawContext))
  }

  public static func setValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawContext = rawContext(from: context) else {
      return false
    }
    switch setProperty(
      key.rawValue,
      on: object.rawValue,
      to: value.rawValue,
      in: rawContext,
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
    guard let rawContext = rawContext(from: context) else {
      return false
    }
    switch setProperty(at: index, on: object.rawValue, to: value.rawValue, in: rawContext) {
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
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return hasProperty(key, on: object.rawValue, in: rawContext)
  }

  public static func hasValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return hasProperty(key.rawValue, on: object.rawValue, in: rawContext)
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    guard let rawContext = rawContext(from: context) else {
      return false
    }
    switch deleteProperty(key, on: object.rawValue, in: rawContext) {
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
    guard let rawContext = rawContext(from: context) else {
      return false
    }
    switch deleteProperty(key.rawValue, on: object.rawValue, in: rawContext) {
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
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    let rawThisValue: JavaScriptCoreRawValue? = thisValue?.rawValue
    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: callFunction(
        function.rawValue,
        this: rawThisValue,
        arguments: rawArguments,
        in: rawContext
      )
    )
  }

  public static func constructHandle(
    _ constructor: JSValueHandle<JavaScriptCoreEngine>,
    arguments: [JSValueHandle<JavaScriptCoreEngine>] = [],
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: construct(constructor.rawValue, arguments: rawArguments, in: rawContext))
  }

  public static func toObjectHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return resultHandle(from: toObject(value.rawValue, in: rawContext))
  }

  public static func isArrayHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return isArray(value.rawValue, in: rawContext)
  }

  public static func isDateHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return isDate(value.rawValue, in: rawContext)
  }

  public static func isInstanceOfHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    constructor: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    guard let rawContext = rawContext(from: context) else {
      return nil
    }
    return isInstanceOf(value.rawValue, constructor: constructor.rawValue, in: rawContext)
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

    return valueHandle(from: objectRef, in: context)
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch objectRef(for: value.rawValue, in: context) {
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
    switch objectRef(for: value.rawValue, in: context) {
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
        type: typedArrayTypeForKind(kind),
        length: length
      )
    else {
      return nil
    }

    return valueHandle(from: objectRef, in: context)
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JavaScriptCoreEngine>
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch objectRef(for: arrayBuffer.rawValue, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeTypedArrayWithArrayBuffer(
          in: context.ref,
          type: typedArrayTypeForKind(kind),
          arrayBuffer: objectRef
        )
      else {
        return nil
      }

      return valueHandle(from: typedArrayRef, in: context)
    }
  }

  public static func makeTypedArrayHandle(
    in context: JavaScriptCoreContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<JavaScriptCoreEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    switch objectRef(for: arrayBuffer.rawValue, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard
        let typedArrayRef = makeTypedArrayWithArrayBufferAndOffset(
          in: context.ref,
          type: typedArrayTypeForKind(kind),
          arrayBuffer: objectRef,
          byteOffset: byteOffset,
          length: length
        )
      else {
        return nil
      }

      return valueHandle(from: typedArrayRef, in: context)
    }
  }

  public static func typedArrayLengthForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Int? {
    switch objectRef(for: value.rawValue, in: context) {
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
    switch objectRef(for: value.rawValue, in: context) {
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
    switch objectRef(for: value.rawValue, in: context) {
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
    switch objectRef(for: value.rawValue, in: context) {
    case .exception:
      return nil
    case .object(let objectRef):
      guard let bufferRef = typedArrayBuffer(of: objectRef, in: context.ref) else {
        return nil
      }

      return valueHandle(from: bufferRef, in: context)
    }
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    switch objectRef(for: value.rawValue, in: context) {
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

    return type == typedArrayTypeArrayBuffer
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

    return typedArrayKindForType(type)
  }

  package static func makeFunctionClass() -> JSClassRef {
    var definition = makeJavaScriptCoreFunctionClassDefinition()
    return JSClassCreate(&definition)!
  }

  package static func makeFunction(
    named name: String,
    callback: @escaping JSFunctionCallback,
    in context: JavaScriptCoreRawContext,
    functionClass: JSClassRef
  ) -> JavaScriptCoreRawValue {
    let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
    guard let functionRef = JSObjectMake(context.ref, functionClass, callbackRef) else {
      let callback = Unmanaged<Box<JSFunctionCallback>>.fromOpaque(callbackRef)
        .takeRetainedValue()
      _ = callback.value
      return makeUndefined(in: context)
    }
    if !name.isEmpty {
      _ = setProperty(
        "name",
        on: JavaScriptCoreRawValue(ref: functionRef, contextRef: context.ref),
        to: makeString(name, in: context),
        in: context,
        attributes: [.dontEnum, .readOnly]
      )
    }
    return JavaScriptCoreRawValue(ref: functionRef, contextRef: context.ref)
  }

  package static func makeObject(
    of jsClass: JSClassRef,
    privateData: UnsafeMutableRawPointer?,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    guard let objectRef = JSObjectMake(context.ref, jsClass, privateData) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreRawValue(ref: objectRef, contextRef: context.ref))
  }

  package static func privateData(
    from value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<UnsafeMutableRawPointer?> {
    switch objectRef(for: value, in: context) {
    case .exception:
      return .exception(nil)
    case .object(let objectRef):
      return .value(JSObjectGetPrivate(objectRef))
    }
  }

  package static func makeObjectResultHandle(
    of jsClass: JSClassRef,
    privateData: UnsafeMutableRawPointer?,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    let rawContext = context

    switch makeObject(of: jsClass, privateData: privateData, in: rawContext) {
    case .value(let value):
      return .value(JSValueHandle<JavaScriptCoreEngine>(rawValue: value))
    case .exception(let exception):
      return .exception(JSValueHandle<JavaScriptCoreEngine>(rawValue: exception))
    }
  }

  package static func privateData(
    from value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSDriverResult<UnsafeMutableRawPointer?>? {
    let rawContext = context

    return privateData(from: value.rawValue, in: rawContext)
  }

  package static func valueRef(from handle: JSValueHandle<JavaScriptCoreEngine>)
    -> JavaScriptCoreValueRef?
  {
    handle.rawValue.ref
  }

  package static func retainedValueRef(from handle: JSValueHandle<JavaScriptCoreEngine>)
    -> JavaScriptCoreValueRef?
  {
    let rawValue = handle.rawValue
    JSValueProtect(rawValue.contextRef, rawValue.ref)
    return rawValue.ref
  }

  package static func contextGroupRef(
    from context: JavaScriptCoreContextHandle
  ) -> JSContextGroupRef? {
    JSContextGetGroup(context.ref)
  }

  package static func contextGroupRef(
    from value: JSValueHandle<JavaScriptCoreEngine>
  ) -> JSContextGroupRef? {
    let rawValue = value.rawValue
    return JSContextGetGroup(rawValue.contextRef)
  }

  package static func valueHandle(
    from rawValue: JavaScriptCoreRawValue
  ) -> JSValueHandle<JavaScriptCoreEngine> {
    JSValueHandle<JavaScriptCoreEngine>(rawValue: rawValue)
  }

  package static func valueHandle(
    from valueRef: JavaScriptCoreValueRef,
    in context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    let rawValue = JavaScriptCoreRawValue(ref: valueRef, contextRef: context.ref)
    return JSValueHandle<JavaScriptCoreEngine>(rawValue: rawValue)
  }

  package static func rawValue(
    from valueRef: JavaScriptCoreValueRef,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: valueRef, contextRef: context.ref)
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
    in context: JavaScriptCoreRawContext
  ) -> String? {
    switch getProperty(
      key,
      on: JavaScriptCoreRawValue(ref: object, contextRef: context.ref),
      in: context
    ) {
    case .exception:
      return nil
    case .value(let value):
      return value.toString()
    }
  }

  package static func toBoolean(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    JSValueToBoolean(context, value)
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

  package static func isUndefined(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .undefined
  }

  package static func isNull(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .null
  }

  package static func isBoolean(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .boolean
  }

  package static func isNumber(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .number
  }

  package static func isString(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .string
  }

  package static func isSymbol(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .symbol
  }

  package static func isObject(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .object
  }

  package static func isBigInt(_ value: JSValueRef, in context: JSContextRef) -> Bool {
    valueType(of: value, in: context) == .bigInt
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

  package static func globalObject(
    in context: JavaScriptCoreGlobalContextRef
  ) -> JavaScriptCoreObjectRef? {
    JSContextGetGlobalObject(context)
  }

  package static var emptyClassDefinition: JavaScriptCoreClassDefinition {
    JavaScriptCore.kJSClassDefinitionEmpty
  }

  package static var classAttributeNoneRawValue: UInt32 {
    UInt32(kJSClassAttributeNone)
  }

  package static var classAttributeNoAutomaticPrototypeRawValue: UInt32 {
    UInt32(kJSClassAttributeNoAutomaticPrototype)
  }

  package static func retainClass(_ jsClass: JavaScriptCoreClassRef) -> JavaScriptCoreClassRef {
    JSClassRetain(jsClass)
  }

  package static func createClass(
    _ definition: inout JavaScriptCoreClassDefinition
  ) -> JavaScriptCoreClassRef {
    JSClassCreate(&definition)
  }

  package static func releaseClass(_ jsClass: JavaScriptCoreClassRef) {
    JSClassRelease(jsClass)
  }

  package static var typedArrayTypeArrayBuffer: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeArrayBuffer
  }

  package static var typedArrayTypeInt8Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeInt8Array
  }

  package static var typedArrayTypeUint8Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeUint8Array
  }

  package static var typedArrayTypeUint8ClampedArray: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeUint8ClampedArray
  }

  package static var typedArrayTypeInt16Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeInt16Array
  }

  package static var typedArrayTypeUint16Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeUint16Array
  }

  package static var typedArrayTypeInt32Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeInt32Array
  }

  package static var typedArrayTypeUint32Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeUint32Array
  }

  package static var typedArrayTypeFloat32Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeFloat32Array
  }

  package static var typedArrayTypeFloat64Array: JavaScriptCoreTypedArrayType {
    kJSTypedArrayTypeFloat64Array
  }

  package static func typedArrayTypeForKind(
    _ kind: JSTypedArrayKind
  ) -> JavaScriptCoreTypedArrayType {
    switch kind {
    case .int8Array:
      return typedArrayTypeInt8Array
    case .uint8Array:
      return typedArrayTypeUint8Array
    case .uint8ClampedArray:
      return typedArrayTypeUint8ClampedArray
    case .int16Array:
      return typedArrayTypeInt16Array
    case .uint16Array:
      return typedArrayTypeUint16Array
    case .int32Array:
      return typedArrayTypeInt32Array
    case .uint32Array:
      return typedArrayTypeUint32Array
    case .float32Array:
      return typedArrayTypeFloat32Array
    case .float64Array:
      return typedArrayTypeFloat64Array
    }
  }

  package static func typedArrayKindForType(
    _ type: JavaScriptCoreTypedArrayType
  ) -> JSTypedArrayKind? {
    switch type {
    case typedArrayTypeInt8Array:
      return .int8Array
    case typedArrayTypeUint8Array:
      return .uint8Array
    case typedArrayTypeUint8ClampedArray:
      return .uint8ClampedArray
    case typedArrayTypeInt16Array:
      return .int16Array
    case typedArrayTypeUint16Array:
      return .uint16Array
    case typedArrayTypeInt32Array:
      return .int32Array
    case typedArrayTypeUint32Array:
      return .uint32Array
    case typedArrayTypeFloat32Array:
      return .float32Array
    case typedArrayTypeFloat64Array:
      return .float64Array
    default:
      return nil
    }
  }

  package static func makeArrayBufferWithBytesNoCopy(
    in context: JavaScriptCoreGlobalContextRef,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: JavaScriptCoreTypedArrayBytesDeallocator?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JavaScriptCoreObjectRef? {
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
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let length = JSObjectGetArrayBufferByteLength(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return length
  }

  package static func arrayBufferBytesPtr(
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var exception: JSValueRef?
    let bytes = JSObjectGetArrayBufferBytesPtr(context, object, &exception)
    return (bytes, exception != nil)
  }

  package static func makeTypedArray(
    in context: JavaScriptCoreGlobalContextRef,
    type: JavaScriptCoreTypedArrayType,
    length: Int
  ) -> JavaScriptCoreObjectRef? {
    var exception: JSValueRef?
    let ref = JSObjectMakeTypedArray(context, type, length, &exception)
    guard exception == nil else {
      return nil
    }
    return ref
  }

  package static func makeTypedArrayWithArrayBuffer(
    in context: JavaScriptCoreGlobalContextRef,
    type: JavaScriptCoreTypedArrayType,
    arrayBuffer: JavaScriptCoreObjectRef
  ) -> JavaScriptCoreObjectRef? {
    var exception: JSValueRef?
    let ref = JSObjectMakeTypedArrayWithArrayBuffer(context, type, arrayBuffer, &exception)
    guard exception == nil else {
      return nil
    }
    return ref
  }

  package static func makeTypedArrayWithArrayBufferAndOffset(
    in context: JavaScriptCoreGlobalContextRef,
    type: JavaScriptCoreTypedArrayType,
    arrayBuffer: JavaScriptCoreObjectRef,
    byteOffset: Int,
    length: Int
  ) -> JavaScriptCoreObjectRef? {
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
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let length = JSObjectGetTypedArrayLength(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return length
  }

  package static func typedArrayByteLength(
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let length = JSObjectGetTypedArrayByteLength(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return length
  }

  package static func typedArrayByteOffset(
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> Int? {
    var exception: JSValueRef?
    let offset = JSObjectGetTypedArrayByteOffset(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return offset
  }

  package static func typedArrayBuffer(
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> JavaScriptCoreObjectRef? {
    var exception: JSValueRef?
    let buffer = JSObjectGetTypedArrayBuffer(context, object, &exception)
    guard exception == nil else {
      return nil
    }
    return buffer
  }

  package static func typedArrayBytesPtr(
    of object: JavaScriptCoreObjectRef,
    in context: JavaScriptCoreContextRef
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    var exception: JSValueRef?
    let bytes = JSObjectGetTypedArrayBytesPtr(context, object, &exception)
    return (bytes, exception != nil)
  }

  package static func typedArrayType(
    of value: JavaScriptCoreValueRef,
    in context: JavaScriptCoreContextRef
  ) -> JavaScriptCoreTypedArrayType? {
    var exception: JSValueRef?
    let type = JSValueGetTypedArrayType(context, value, &exception)
    guard exception == nil else {
      return nil
    }
    return type
  }

  package static func unprotect(
    _ value: JavaScriptCoreValueRef,
    in context: JavaScriptCoreContextRef
  ) {
    JSValueUnprotect(context, value)
  }

  package static func protect(
    _ value: JavaScriptCoreValueRef,
    in context: JavaScriptCoreContextRef
  ) {
    JSValueProtect(context, value)
  }

  package static func valueEquals(
    _ lhs: JavaScriptCoreValueRef,
    _ rhs: JavaScriptCoreValueRef,
    in context: JavaScriptCoreContextRef
  ) -> Bool {
    JSValueIsEqual(context, lhs, rhs, nil)
  }

  package static func valueStrictEquals(
    _ lhs: JavaScriptCoreValueRef,
    _ rhs: JavaScriptCoreValueRef,
    in context: JavaScriptCoreContextRef
  ) -> Bool {
    JSValueIsStrictEqual(context, lhs, rhs)
  }

  package static func undefinedValue(
    in context: JavaScriptCoreContextRef?
  ) -> JavaScriptCoreValueRef? {
    JSValueMakeUndefined(context)
  }

  package static func toNumber(_ value: JSValueRef, in context: JSContextRef) -> Double {
    JSValueToNumber(context, value, nil)
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

  package static func hostTypeDescriptor(
    for definition: JSClassDefinition,
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer
  ) -> JSHostTypeDescriptor {
    definition.hostTypeDescriptor(storagePolicy: storagePolicy)
  }

  package static func hasDynamicPropertyGetter(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.dynamicPropertyGetterBinding != nil
  }

  package static func hasDynamicPropertySetter(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.dynamicPropertySetterBinding != nil
  }

  package static func hasDynamicPropertyHas(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.dynamicPropertyHasBinding != nil
  }

  package static func hasDynamicPropertyDelete(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.dynamicPropertyDeleteBinding != nil
  }

  package static func hasPropertyEnumerator(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.propertyEnumeratorBinding != nil
  }

  package static func hasCallAsFunction(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.callAsFunctionBinding != nil
  }

  package static func hasConstructor(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.constructor?.binding != nil
  }

  package static func hasHasInstance(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.hasInstanceBinding != nil
  }

  package static func hasConvertToType(for descriptor: JSHostTypeDescriptor) -> Bool {
    descriptor.convertToTypeBinding != nil
  }

  package static func propertyAttributes(from attributes: JSHostMemberAttributes) -> UInt32 {
    javaScriptCorePropertyAttributes(from: attributes)
  }

  package static func withArguments<R: ~Copyable>(
    _ pointer: UnsafePointer<JSValueRef?>?,
    count: Int,
    _ body: (borrowing JSArguments<JavaScriptCoreEngine>) -> R
  ) -> R {
    withJavaScriptCoreArguments(pointer, count: count, body)
  }

  static func withDynamicPropertyCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    propertyName: JSStringRef?,
    _ body: (
      JSClassDefinition, borrowing JSInstantContext,
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
      JSClassDefinition, borrowing JSInstantContext,
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
      JSClassDefinition, borrowing JSInstantContext,
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
      JSClassDefinition, borrowing JSInstantContext,
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
      JSClassDefinition,
      borrowing JSInstantContext,
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
      JSClassDefinition, borrowing JSInstantContext,
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
      JSStaticValue, borrowing JSInstantContext,
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
        resolvingParentDefinition: resolveParentDefinition
      )
    else {
      return nil
    }

    let context = JSInstantContext(ctx: ctx)
    let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
    return body(valueDefinition, context, thisValue)
  }

  static func withStaticFunctionCallbackInput<R>(
    ctx: JSContextRef?,
    function: JSObjectRef?,
    thisObject: JSObjectRef?,
    _ body: (
      JSStaticFunction, borrowing JSInstantContext,
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
    let functionName = functionValue.getProperty(forKey: JSStringManaged("name"), in: context)
      .toString(in: context)
    guard
      let functionDefinition = definition.inheritedStaticFunction(
        named: functionName,
        resolvingParentDefinition: resolveParentDefinition
      )
    else {
      return nil
    }

    let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObject, ctx: context)
    return body(functionDefinition, context, thisValue)
  }

  static func callbackReturnValue(
    _ result: borrowing JSResult<JavaScriptCoreValueRef>,
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
    _ result: borrowing JSResult<JavaScriptCoreValueRef>,
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
    in context: JavaScriptCoreRawContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
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
          return .exception(JavaScriptCoreRawValue(ref: exception, contextRef: context.ref))
        }

        if let resultRef {
          return .value(JavaScriptCoreRawValue(ref: resultRef, contextRef: context.ref))
        }

        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func makeString(
    _ value: String,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    withJSString(value) { stringHandle in
      JavaScriptCoreRawValue(
        ref: JSValueMakeString(context.ref, stringHandle)!, contextRef: context.ref)
    }
  }

  package static func makeSymbol(
    _ value: String,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    withJSString(value) { stringHandle in
      JavaScriptCoreRawValue(
        ref: JSValueMakeSymbol(context.ref, stringHandle)!, contextRef: context.ref)
    }
  }

  package static func makeNumber(
    _ value: Double,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: JSValueMakeNumber(context.ref, value)!, contextRef: context.ref)
  }

  package static func makeBoolean(
    _ value: Bool,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: JSValueMakeBoolean(context.ref, value)!, contextRef: context.ref)
  }

  package static func makeNull(in context: JavaScriptCoreRawContext)
    -> JavaScriptCoreRawValue
  {
    JavaScriptCoreRawValue(ref: JSValueMakeNull(context.ref)!, contextRef: context.ref)
  }

  package static func makeUndefined(in context: JavaScriptCoreRawContext)
    -> JavaScriptCoreRawValue
  {
    JavaScriptCoreRawValue(ref: JSValueMakeUndefined(context.ref)!, contextRef: context.ref)
  }

  package static func makeObject(in context: JavaScriptCoreRawContext)
    -> JSDriverResult<JavaScriptCoreRawValue>
  {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreRawValue(ref: objectRef, contextRef: context.ref))
  }

  package static func makeArray(in context: JavaScriptCoreRawContext)
    -> JSDriverResult<JavaScriptCoreRawValue>
  {
    var exception: JSValueRef?
    let objectRef = JSObjectMakeArray(context.ref, 0, nil, &exception)
    if let exception {
      return .exception(JavaScriptCoreRawValue(ref: exception, contextRef: context.ref))
    }
    if let objectRef {
      return .value(JavaScriptCoreRawValue(ref: objectRef, contextRef: context.ref))
    }
    return .value(makeUndefined(in: context))
  }

  package static func propertyNames(
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        let valueRef = JSObjectGetProperty(context.ref, objectRef, keyRef, &exception)
        if let exception {
          return .exception(JavaScriptCoreRawValue(ref: exception, contextRef: context.ref))
        }
        if let valueRef {
          return .value(JavaScriptCoreRawValue(ref: valueRef, contextRef: context.ref))
        }
        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func getProperty(
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
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
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
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
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    _ function: JavaScriptCoreRawValue,
    this thisValue: JavaScriptCoreRawValue?,
    arguments: [JavaScriptCoreRawValue],
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
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
    _ constructor: JavaScriptCoreRawValue,
    arguments: [JavaScriptCoreRawValue],
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
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
    _ value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: value, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return .value(JavaScriptCoreRawValue(ref: objectRef, contextRef: context.ref))
    }
  }

  package static func isArray(
    _ value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    JSValueIsArray(context.ref, value.ref)
  }

  package static func isDate(
    _ value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    JSValueIsDate(context.ref, value.ref)
  }

  package static func isInstanceOf(
    _ value: JavaScriptCoreRawValue,
    constructor: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    on object: JavaScriptCoreRawValue,
    to value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext,
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
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    to value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext,
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
    on object: JavaScriptCoreRawValue,
    to value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
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
    for value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreObjectLookup {
    var exception: JSValueRef?
    guard let objectRef = JSValueToObject(context.ref, value.ref, &exception) else {
      if let exception {
        return .exception(JavaScriptCoreRawValue(ref: exception, contextRef: context.ref))
      }
      return .exception(makeUndefined(in: context))
    }
    return .object(objectRef)
  }

  private static func result(
    value resultRef: JSValueRef?,
    exception exceptionRef: JSValueRef?,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    if let exceptionRef {
      return .exception(JavaScriptCoreRawValue(ref: exceptionRef, contextRef: context.ref))
    }
    if let resultRef {
      return .value(JavaScriptCoreRawValue(ref: resultRef, contextRef: context.ref))
    }
    return .value(makeUndefined(in: context))
  }
}

private func javaScriptCorePropertyAttributes(from attributes: JSHostMemberAttributes) -> UInt32 {
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
