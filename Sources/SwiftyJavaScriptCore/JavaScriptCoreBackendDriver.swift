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

package final class JavaScriptCoreRawRuntime: @unchecked Sendable {
  package let ref: JSContextGroupRef

  package init(ref: JSContextGroupRef = JSContextGroupCreate()) {
    self.ref = ref
  }

  deinit {
    JSContextGroupRelease(ref)
  }
}

package final class JavaScriptCoreRawContext: @unchecked Sendable {
  package let runtime: JavaScriptCoreRawRuntime?
  package let ref: JSGlobalContextRef
  private let ownsContext: Bool

  package init(runtime: JavaScriptCoreRawRuntime) {
    self.runtime = runtime
    self.ref = JSGlobalContextCreateInGroup(runtime.ref, nil)
    self.ownsContext = true
  }

  package init(borrowing ref: JSGlobalContextRef) {
    self.runtime = nil
    self.ref = ref
    self.ownsContext = false
  }

  deinit {
    if ownsContext {
      JSGlobalContextRelease(ref)
    }
  }
}

package final class JavaScriptCoreRawValue: @unchecked Sendable {
  package let ref: JSValueRef
  package let context: JavaScriptCoreRawContext

  package init(ref: JSValueRef, context: JavaScriptCoreRawContext) {
    self.ref = ref
    self.context = context
    JSValueProtect(context.ref, ref)
  }

  deinit {
    JSValueUnprotect(context.ref, ref)
  }

  package var type: SwiftJavaScript.JSType {
    JavaScriptCoreBackendDriver.valueType(of: ref, in: context.ref)
  }

  package func toDouble() -> Double {
    JSValueToNumber(context.ref, ref, nil)
  }

  package func toString() -> String? {
    guard let stringRef = JSValueToStringCopy(context.ref, ref, nil) else {
      return nil
    }
    defer { JSStringRelease(stringRef) }
    return String(jsStringRef: stringRef)
  }
}

private let javaScriptCoreFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSInstantContext(ctx: ctx)
  let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(
    JSObjectGetPrivate(function)!
  ).takeUnretainedValue().value
  let functionValue = JSValue(ref: function, ctx: context)
  let thisValue = JSValue(ref: thisObject, ctx: context)
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
    let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

private func withJavaScriptCoreArguments<R: ~Copyable>(
  _ pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSArguments) -> R
) -> R {
  var empty: JSValueRef? = nil
  return withUnsafePointer(to: &empty) { emptyPointer in
    let arguments = JSArguments(pointer: pointer ?? emptyPointer, count: count)
    return body(arguments)
  }
}

private enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JavaScriptCoreRawValue)
}

package enum JavaScriptCoreBackendDriver: _JSEngineDriver {
  package typealias Engine = JavaScriptCoreEngine
  package typealias RawRuntime = JavaScriptCoreRawRuntime
  package typealias RawContext = JavaScriptCoreRawContext
  package typealias RawValue = JavaScriptCoreRawValue

  package static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  package static func makeRuntime() -> JavaScriptCoreRawRuntime {
    JavaScriptCoreRawRuntime()
  }

  package static func makeContext(in runtime: JavaScriptCoreRawRuntime)
    -> JavaScriptCoreRawContext
  {
    JavaScriptCoreRawContext(runtime: runtime)
  }

  package static func makeFunctionClass() -> JSClassRef {
    var definition = makeJavaScriptCoreFunctionClassDefinition()
    return JSClassCreate(&definition)!
  }

  package static func makeFunction(
    named name: String,
    callback: @escaping JSValue.JSFunctionCallback,
    in context: JavaScriptCoreRawContext,
    functionClass: JSClassRef
  ) -> JavaScriptCoreRawValue {
    let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
    guard let functionRef = JSObjectMake(context.ref, functionClass, callbackRef) else {
      let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(callbackRef)
        .takeRetainedValue()
      _ = callback.value
      return makeUndefined(in: context)
    }
    if !name.isEmpty {
      _ = setProperty(
        "name",
        on: JavaScriptCoreRawValue(ref: functionRef, context: context),
        to: makeString(name, in: context),
        in: context,
        attributes: [.dontEnum, .readOnly]
      )
    }
    return JavaScriptCoreRawValue(ref: functionRef, context: context)
  }

  package static func makeObject(
    of jsClass: JSClassRef,
    privateData: UnsafeMutableRawPointer?,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    guard let objectRef = JSObjectMake(context.ref, jsClass, privateData) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
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
    in context: JSBorrowedContextHandle<JavaScriptCoreEngine>
  ) -> JSResultHandle<JavaScriptCoreEngine>? {
    guard let rawContext: JavaScriptCoreRawContext = context.opaqueHandle() else {
      return nil
    }

    switch makeObject(of: jsClass, privateData: privateData, in: rawContext) {
    case .value(let value):
      return .value(JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: value))
    case .exception(let exception):
      return .exception(JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: exception))
    }
  }

  package static func privateData(
    from value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JSBorrowedContextHandle<JavaScriptCoreEngine>
  ) -> JSDriverResult<UnsafeMutableRawPointer?>? {
    guard let rawValue: JavaScriptCoreRawValue = value.opaqueHandle(),
      let rawContext: JavaScriptCoreRawContext = context.opaqueHandle()
    else {
      return nil
    }

    return privateData(from: rawValue, in: rawContext)
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
      on: JavaScriptCoreRawValue(ref: object, context: context),
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

  package static func stringLength(_ stringRef: JavaScriptCoreStringRef) -> Int {
    JSStringGetLength(stringRef)
  }

  package static func stringCharacters(
    _ stringRef: JavaScriptCoreStringRef
  ) -> UnsafePointer<UInt16>? {
    JSStringGetCharactersPtr(stringRef)
  }

  package static func retain(_ stringRef: JavaScriptCoreStringRef) -> JavaScriptCoreStringRef {
    JSStringRetain(stringRef)
  }

  package static func release(_ stringRef: JavaScriptCoreStringRef) {
    JSStringRelease(stringRef)
  }

  package static func makeJSString(_ value: String) -> JavaScriptCoreStringRef {
    JSStringCreateWithCFString(value as CFString)
  }

  package static func stringEquals(
    _ lhs: JavaScriptCoreStringRef,
    _ rhs: JavaScriptCoreStringRef
  ) -> Bool {
    JSStringIsEqual(lhs, rhs)
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
    guard let stringRef = JSValueToStringCopy(context, value, nil) else {
      return nil
    }
    defer { JSStringRelease(stringRef) }
    return String(jsStringRef: stringRef)
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
    _ body: (borrowing JSArguments) -> R
  ) -> R {
    withJavaScriptCoreArguments(pointer, count: count, body)
  }

  static func withDynamicPropertyCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    propertyName: JSStringRef?,
    _ body: (JSClassDefinition, borrowing JSInstantContext, borrowing JSValue, String) -> R
  ) -> R? {
    guard let ctx, let object,
      let definition = classDefinition(from: object),
      let propertyName = classPropertyName(propertyName)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, object)
    let thisValue = JSValue(ref: object, ctx: context)
    return body(definition, context, thisValue, propertyName)
  }

  static func withFunctionCallbackInput<R>(
    ctx: JSContextRef?,
    functionRef: JSObjectRef?,
    thisObjectRef: JSObjectRef?,
    _ body: (JSClassDefinition, borrowing JSInstantContext, inout JSValue, inout JSValue) -> R
  ) -> R? {
    guard let ctx, let functionRef, let thisObjectRef,
      let definition = classDefinition(from: thisObjectRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, thisObjectRef)
    var functionValue = JSValue(ref: functionRef, ctx: context)
    var thisValue = JSValue(ref: thisObjectRef, ctx: context)
    return body(definition, context, &functionValue, &thisValue)
  }

  static func withConstructorCallbackInput<R>(
    ctx: JSContextRef?,
    constructorRef: JSObjectRef?,
    _ body: (JSClassDefinition, borrowing JSInstantContext, inout JSValue, inout JSValue) -> R
  ) -> R? {
    guard let ctx, let constructorRef,
      let definition = classDefinition(from: constructorRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, constructorRef)
    var constructorValue = JSValue(ref: constructorRef, ctx: context)
    var thisValue = JSValue(undefinedIn: context)
    return body(definition, context, &constructorValue, &thisValue)
  }

  static func withHasInstanceCallbackInput<R>(
    ctx: JSContextRef?,
    constructorRef: JSObjectRef?,
    possibleInstanceRef: JSObjectRef?,
    _ body: (JSClassDefinition, borrowing JSInstantContext, inout JSValue, inout JSValue) -> R
  ) -> R? {
    guard let ctx, let constructorRef, let possibleInstanceRef,
      let definition = classDefinition(from: constructorRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, constructorRef)
    var constructorValue = JSValue(ref: constructorRef, ctx: context)
    var possibleInstanceValue = JSValue(ref: possibleInstanceRef, ctx: context)
    return body(definition, context, &constructorValue, &possibleInstanceValue)
  }

  static func withConvertToTypeCallbackInput<R>(
    ctx: JSContextRef?,
    objectRef: JSObjectRef?,
    jsType: SwiftJavaScript.JSType,
    _ body: (
      JSClassDefinition,
      borrowing JSInstantContext,
      inout JSValue,
      SwiftJavaScript.JSType,
      inout JSValue
    ) ->
      R
  ) -> R? {
    guard let ctx, let objectRef,
      let definition = classDefinition(from: objectRef)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, objectRef)
    var objectValue = JSValue(ref: objectRef, ctx: context)
    var exceptionValue = JSValue(undefinedIn: context)
    return body(definition, context, &objectValue, jsType, &exceptionValue)
  }

  static func withPropertyNamesCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    accumulator: JSPropertyNameAccumulatorRef?,
    _ body: (
      JSClassDefinition, borrowing JSInstantContext, inout JSValue, JSPropertyNameAccumulatorRef
    ) -> R
  ) -> R? {
    guard let ctx, let object, let accumulator,
      let definition = classDefinition(from: object)
    else {
      return nil
    }

    let context = makeRememberedClassCallbackContext(ctx, object)
    var thisValue = JSValue(ref: object, ctx: context)
    return body(definition, context, &thisValue, accumulator)
  }

  static func withStaticValueCallbackInput<R>(
    ctx: JSContextRef?,
    object: JSObjectRef?,
    propertyName: JSStringRef?,
    _ body: (JSStaticValue, borrowing JSInstantContext, borrowing JSValue) -> R
  ) -> R? {
    guard let ctx, let object,
      let definition = classDefinition(from: object),
      let propertyName = classPropertyName(propertyName)
    else {
      return nil
    }

    rememberClassObjectContext(ctx, object)
    guard let valueDefinition = inheritedStaticValue(named: propertyName, from: definition) else {
      return nil
    }

    let context = JSInstantContext(ctx: ctx)
    let thisValue = JSValue(ref: object, ctx: context)
    return body(valueDefinition, context, thisValue)
  }

  static func withStaticFunctionCallbackInput<R>(
    ctx: JSContextRef?,
    function: JSObjectRef?,
    thisObject: JSObjectRef?,
    _ body: (JSStaticFunction, borrowing JSInstantContext, borrowing JSValue) -> R
  ) -> R? {
    guard let ctx, let function, let thisObject,
      let definition = classDefinition(from: thisObject)
    else {
      return nil
    }

    rememberClassObjectContext(ctx, thisObject)
    let context = makeRememberedClassCallbackContext(ctx, thisObject)
    let functionValue = JSValue(ref: function, ctx: context)
    let functionName = functionValue.getProperty(forKey: JSStringManaged("name"), in: context)
      .toString(in: context)
    guard
      let functionDefinition = inheritedStaticFunction(named: functionName, from: definition)
    else {
      return nil
    }

    let thisValue = JSValue(ref: thisObject, ctx: context)
    return body(functionDefinition, context, thisValue)
  }

  static func callbackReturnValue(
    _ result: JSPrivateResult,
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
    _ result: JSPrivateResult,
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
          return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
        }

        if let resultRef {
          return .value(JavaScriptCoreRawValue(ref: resultRef, context: context))
        }

        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func makeString(
    _ value: String,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    withJSString(value) { stringRef in
      JavaScriptCoreRawValue(ref: JSValueMakeString(context.ref, stringRef)!, context: context)
    }
  }

  package static func makeSymbol(
    _ value: String,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    withJSString(value) { stringRef in
      JavaScriptCoreRawValue(ref: JSValueMakeSymbol(context.ref, stringRef)!, context: context)
    }
  }

  package static func makeNumber(
    _ value: Double,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: JSValueMakeNumber(context.ref, value)!, context: context)
  }

  package static func makeBoolean(
    _ value: Bool,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: JSValueMakeBoolean(context.ref, value)!, context: context)
  }

  package static func makeNull(in context: JavaScriptCoreRawContext)
    -> JavaScriptCoreRawValue
  {
    JavaScriptCoreRawValue(ref: JSValueMakeNull(context.ref)!, context: context)
  }

  package static func makeUndefined(in context: JavaScriptCoreRawContext)
    -> JavaScriptCoreRawValue
  {
    JavaScriptCoreRawValue(ref: JSValueMakeUndefined(context.ref)!, context: context)
  }

  package static func makeObject(in context: JavaScriptCoreRawContext)
    -> JSDriverResult<JavaScriptCoreRawValue>
  {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
  }

  package static func makeArray(in context: JavaScriptCoreRawContext)
    -> JSDriverResult<JavaScriptCoreRawValue>
  {
    var exception: JSValueRef?
    let objectRef = JSObjectMakeArray(context.ref, 0, nil, &exception)
    if let exception {
      return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
    }
    if let objectRef {
      return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
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
        guard let keyRef = JSPropertyNameArrayGetNameAtIndex(names, index) else {
          continue
        }
        result.append(String(jsStringRef: keyRef))
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
          return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
        }
        if let valueRef {
          return .value(JavaScriptCoreRawValue(ref: valueRef, context: context))
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
      return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
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
        return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
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
      return .exception(JavaScriptCoreRawValue(ref: exceptionRef, context: context))
    }
    if let resultRef {
      return .value(JavaScriptCoreRawValue(ref: resultRef, context: context))
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
  let ref = JSStringCreateWithCFString(string as CFString)!
  defer { JSStringRelease(ref) }
  return body(ref)
}

private func withOptionalJSString<R>(_ string: String?, _ body: (JSStringRef?) -> R) -> R {
  guard let string else {
    return body(nil)
  }
  return withJSString(string, body)
}
