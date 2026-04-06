import Foundation
import JavaScriptCore

private final class JSClassCacheRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [ObjectIdentifier: JSClass] = [:]

  func jsClass<T: JSClassValueConvertible>(for type: T.Type) -> JSClass {
    let key = ObjectIdentifier(type)

    lock.lock()
    if let existing = map[key] {
      lock.unlock()
      return existing
    }
    lock.unlock()

    let created = T.makeAutoJSClass()

    lock.lock()
    if let existing = map[key] {
      lock.unlock()
      return existing
    }
    map[key] = created
    lock.unlock()
    return created
  }
}

private final class JSClassAutoNativeClassBacking {
  let definition:
    SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >
  let usesManagedParent: Bool
  var staticValueNames: [ContiguousArray<CChar>] = []
  var staticValues: [JavaScriptCore.JSStaticValue] = []
  var staticFunctionNames: [ContiguousArray<CChar>] = []
  var staticFunctions: [JavaScriptCore.JSStaticFunction] = []

  init(
    definition: SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >, usesManagedParent: Bool
  ) {
    self.definition = definition
    self.usesManagedParent = usesManagedParent
  }
}

final class JSClassAutoObjectStorage {
  let definition:
    SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >
  let instance: AnyObject
  let finalizeDepth: Int

  init(
    definition: SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >, instance: AnyObject, finalizeDepth: Int
  ) {
    self.definition = definition
    self.instance = instance
    self.finalizeDepth = finalizeDepth
  }
}

private let jsClassCacheRegistry = JSClassCacheRegistry()

public protocol JSClassValueConvertible: AnyObject, JSValueEncodable,
  JSClassValueConverterCompatible
{
  static var jsClassDefinition:
    SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >
  { get }
  static func decode(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) -> Self
  static func tryDecode(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> Self
  static func encode(_ value: Self, in context: borrowing JSInstantContext<JavaScriptCoreEngine>)
    -> SwiftJavaScript.JSValue<
      JavaScriptCoreEngine
    >
  static func tryEncode(
    _ value: Self,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> SwiftJavaScript.JSValue<JavaScriptCoreEngine>
}

extension JSClassValueConvertible {
  public static var jsClass: JSClass {
    jsClassCacheRegistry.jsClass(for: Self.self)
  }

  fileprivate static func makeAutoJSClass() -> JSClass {
    let definition = jsClassDefinition
    let usesManagedParent =
      definition.parentClass.map { classDefinition(for: $0.ref) != nil } ?? false
    let backing = JSClassAutoNativeClassBacking(
      definition: definition,
      usesManagedParent: usesManagedParent
    )
    let nativeDefinition = autoNativeDefinition(backing: backing)
    return JSClass(
      nativeDefinition: nativeDefinition,
      retainedBacking: backing,
      rememberedDefinition: definition
    )
  }

  public static func decode<E: JSEngine>(
    _ value: borrowing SwiftJavaScript.JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Self {
    let decodeJSC:
      (
        borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
        borrowing JSInstantContext<JavaScriptCoreEngine>
      ) -> Self = Self.decode
    let jscValue = _bridgeJavaScriptCoreValue(value)
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return decodeJSC(jscValue, jscContext)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing SwiftJavaScript.JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self {
    let tryDecodeJSC:
      (
        borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
        borrowing JSInstantContext<JavaScriptCoreEngine>
      ) throws(JSValueConversionError) -> Self = Self.tryDecode
    let jscValue = _bridgeJavaScriptCoreValue(value)
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return try tryDecodeJSC(jscValue, jscContext)
  }

  public static func encode<E: JSEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) -> SwiftJavaScript.JSValue<E> {
    let encodeJSC:
      (Self, borrowing JSInstantContext<JavaScriptCoreEngine>)
        -> SwiftJavaScript.JSValue<JavaScriptCoreEngine> = Self.encode
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return _asGenericValue(encodeJSC(value, jscContext))
  }

  public static func tryEncode<E: JSEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftJavaScript.JSValue<E> {
    let tryEncodeJSC:
      (Self, borrowing JSInstantContext<JavaScriptCoreEngine>)
        throws(JSValueConversionError) -> SwiftJavaScript.JSValue<JavaScriptCoreEngine> =
        Self.tryEncode
    let jscContext = _bridgeJavaScriptCoreContext(context)
    let encoded = try tryEncodeJSC(value, jscContext)
    return _asGenericValue(encoded)
  }

  public static func decode(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  )
    -> Self
  {
    do {
      return try tryDecode(value, in: context)
    } catch {
      fatalError("\(Self.self).decode(_:in:) failed: \(error)")
    }
  }

  public static func tryDecode(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> Self {
    guard value.isObject(in: context) else {
      throw .typeMismatch(expected: "object", actual: value.type(in: context))
    }
    let privateData: UnsafeMutableRawPointer?
    switch JavaScriptCoreEngine.privateData(
      from: value.valueHandle(),
      in: context.driverContextHandle
    ) {
    case .none:
      throw .codable("\(Self.self) driver handle bridge failed")
    case .exception:
      throw .codable("\(Self.self) could not be converted to JSObjectRef")
    case .value(let data):
      privateData = data
    }

    guard let privateData else {
      throw .codable("\(Self.self) does not have a Swift instance backing")
    }

    let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
    guard let instance = storage.instance as? Self else {
      throw .codable("JS object backing is not of type \(Self.self)")
    }

    return instance
  }

  public static func encode(
    _ value: Self, in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  )
    -> SwiftJavaScript.JSValue<
      JavaScriptCoreEngine
    >
  {
    do {
      return try tryEncode(value, in: context)
    } catch {
      return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
    }
  }

  public static func tryEncode(
    _ value: Self,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
    let definition = Self.jsClassDefinition
    let storage = JSClassAutoObjectStorage(
      definition: definition,
      instance: value,
      finalizeDepth: definition.exportedDefinitionCount(
        resolvingParentDefinition: resolveParentDefinition
      )
    )
    let data = Unmanaged.passRetained(storage).toOpaque()

    switch JavaScriptCoreEngine.makeObjectResultHandle(
      of: Self.jsClass.ref,
      privateData: data,
      in: context.driverContextHandle
    ) {
    case .none:
      _ = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(data).takeRetainedValue()
      throw .codable("Driver handle bridge failed to create JS object for \(Self.self)")
    case .some(.exception):
      _ = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(data).takeRetainedValue()
      throw .codable("Failed to create JS object for \(Self.self)")
    case .some(.value(let object)):
      return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(handleValue: object)
    }
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> SwiftJavaScript.JSValue<E> {
    Self.encode(self, in: context)
  }

  public func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftJavaScript.JSValue<E> {
    try Self.tryEncode(self, in: context)
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine> = #isolation
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try T.tryDecode(self, in: callbackContext)
    }
  }
}

private let autoClassInitializeCallback: JSObjectInitializeCallback = { ctx, object in
  guard let ctx, let object,
    let (storage, _) = autoClassStorageRecord(from: object)
  else {
    return
  }

  if let initialize = storage.definition.initialize {
    withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
      initialize(thisValue, context)
    }
  }
}

private let autoClassFinalizeCallback: JSObjectFinalizeCallback = { object in
  guard let object,
    let (storage, privateData) = autoClassStorageRecord(from: object)
  else {
    return
  }

  if let finalize = storage.definition.finalize {
    withStoredClassObjectValue(object) { _, thisValue in
      finalize(thisValue)
    }
  }

  let remaining = storage.finalizeDepth - 1
  if remaining <= 0 {
    removeClassObjectContext(object)
    _ = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeRetainedValue()
  }
}

private func autoClassStorageRecord(from object: JSObjectRef)
  -> (storage: JSClassAutoObjectStorage, privateData: UnsafeMutableRawPointer)?
{
  guard let privateData = JavaScriptCoreEngine.privateData(from: object) else {
    return nil
  }
  let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
  return (storage, privateData)
}

private func autoClassStorage(from object: JSObjectRef) -> JSClassAutoObjectStorage? {
  autoClassStorageRecord(from: object)?.storage
}

private func autoClassDefinition(from object: JSObjectRef) -> SwiftJavaScript
  .JSClassDefinition<JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef>?
{
  autoClassStorage(from: object)?.definition
}

private func autoCallbackValueOrUndefined(
  _ value: JSValueRef?, in ctx: JSContextRef?
)
  -> JSValueRef?
{
  value ?? JavaScriptCoreEngine.undefinedValue(in: ctx)
}

private func autoCallbackValueOrUndefined(
  _ value: JSValueRef??, in ctx: JSContextRef?
)
  -> JSValueRef?
{
  value ?? JavaScriptCoreEngine.undefinedValue(in: ctx)
}

private func autoCallbackSucceededOrFalse(_ value: Bool?) -> Bool {
  value ?? false
}

private func withAutoDynamicPropertyCallbackInput<R>(
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
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return nil
  }

  let key = String(
    jsStringHandle: JavaScriptCoreStringHandle(ref: propertyName),
    engine: JavaScriptCoreEngine.self
  )
  return withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
    body(definition, context, thisValue, key)
  }
}

private func withAutoDynamicPropertyValueCallback(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >, borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, String
  ) ->
    JSValueRef?
) -> JSValueRef? {
  let value = withAutoDynamicPropertyCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName,
    body
  )
  return autoCallbackValueOrUndefined(value, in: ctx)
}

private func withAutoDynamicPropertyBoolCallback(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >, borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, String
  ) -> Bool
) -> Bool {
  let value = withAutoDynamicPropertyCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName,
    body
  )
  return autoCallbackSucceededOrFalse(value)
}

private func autoDynamicGetPropertyCallbackValue(
  definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  key: String,
  ctx: JSContextRef?,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
  guard let getProperty = definition.getProperty else {
    return JavaScriptCoreEngine.undefinedValue(in: ctx)
  }
  return JavaScriptCoreEngine.callbackReturnValue(
    getProperty(context, thisValue, key).toPrivateResult(),
    in: ctx,
    exception: exception
  )
}

private func autoDynamicSetPropertyCallbackResult(
  definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  key: String,
  newValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  guard let setProperty = definition.setProperty else {
    return true
  }
  if let error = setProperty(context, thisValue, key, newValue) {
    let privateResult = JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>.exception(error)
      .toPrivateResult()
    guard case .exception(let errorRef) = privateResult else {
      return true
    }
    return JavaScriptCoreEngine.callbackSucceeded(
      exceptionValue: errorRef,
      exception: exception
    )
  }
  return true
}

private func autoDynamicHasPropertyCallbackResult(
  definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  key: String
) -> Bool {
  definition.hasProperty?(context, thisValue, key) ?? false
}

private func autoDynamicDeletePropertyCallbackResult(
  definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  key: String
) -> Bool {
  definition.deleteProperty?(context, thisValue, key) ?? false
}

private func withAutoStaticValueCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return nil
  }

  let name = String(
    jsStringHandle: JavaScriptCoreStringHandle(ref: propertyName),
    engine: JavaScriptCoreEngine.self
  )
  guard
    let valueDefinition = definition.inheritedStaticValue(
      named: name,
      resolvingParentDefinition: resolveParentDefinition
    )
  else {
    return nil
  }

  return withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
    body(valueDefinition, context, thisValue)
  }
}

private func withAutoStaticValuePropertyCallback(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) ->
    JSValueRef?
) -> JSValueRef? {
  let value = withAutoStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName,
    body
  )
  return autoCallbackValueOrUndefined(value, in: ctx)
}

private func withAutoStaticValueBooleanCallback(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) ->
    Bool
) -> Bool {
  let value = withAutoStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName,
    body
  )
  return autoCallbackSucceededOrFalse(value)
}

private func withAutoStaticFunctionCallbackInput<R>(
  ctx: JSContextRef?,
  function: JSObjectRef?,
  thisObject: JSObjectRef?,
  _ body: (
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) ->
    R
) -> R? {
  guard let ctx, let function, let thisObject,
    let definition = autoClassDefinition(from: thisObject)
  else {
    return nil
  }

  return withRememberedClassObjectValue(ctx, object: thisObject) { context, thisValue in
    let functionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: function, ctx: context)
    let functionName = functionValue.getProperty(
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("name"), in: context
    )
    .toString(in: context)
    guard
      let functionDefinition = definition.inheritedStaticFunction(
        named: functionName,
        resolvingParentDefinition: resolveParentDefinition
      )
    else {
      return nil
    }
    return body(functionDefinition, context, thisValue)
  }
}

private func withAutoStaticFunctionValueCallback(
  ctx: JSContextRef?,
  function: JSObjectRef?,
  thisObject: JSObjectRef?,
  _ body: (
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) ->
    JSValueRef?
) -> JSValueRef? {
  let value = withAutoStaticFunctionCallbackInput(
    ctx: ctx,
    function: function,
    thisObject: thisObject,
    body
  )
  return autoCallbackValueOrUndefined(value, in: ctx)
}

private func autoStaticGetPropertyCallbackValue(
  valueDefinition: SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  ctx: JSContextRef?,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
  JavaScriptCoreEngine.callbackReturnValue(
    valueDefinition.getProperty(context, thisValue).toPrivateResult(),
    in: ctx,
    exception: exception
  )
}

private func autoStaticSetPropertyCallbackResult(
  valueDefinition: SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  newValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  switch valueDefinition.setProperty(context, thisValue, newValue).toPrivateResult() {
  case .value:
    return true
  case .exception(let error):
    return JavaScriptCoreEngine.callbackSucceeded(
      exceptionValue: error,
      exception: exception
    )
  }
}

private func autoStaticFunctionCallCallbackValue(
  functionDefinition: SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  argumentCount: Int,
  arguments: UnsafePointer<JSValueRef?>?,
  ctx: JSContextRef?,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
  let result = JavaScriptCoreEngine.withArguments(arguments, count: argumentCount) { args in
    functionDefinition.callAsFunction(context, thisValue, args).toPrivateResult()
  }
  return JavaScriptCoreEngine.callbackReturnValue(
    result,
    in: ctx,
    exception: exception
  )
}

private let autoStaticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  withAutoStaticValuePropertyCallback(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    autoStaticGetPropertyCallbackValue(
      valueDefinition: valueDefinition,
      context: context,
      thisValue: thisValue,
      ctx: ctx,
      exception: exception
    )
  }
}

private let autoStaticValueSetPropertyCallback: JSObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let value else {
    return false
  }
  return withAutoStaticValueBooleanCallback(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    let newValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: value, ctx: context)
    return autoStaticSetPropertyCallbackResult(
      valueDefinition: valueDefinition,
      context: context,
      thisValue: thisValue,
      newValue: newValue,
      exception: exception
    )
  }
}

private let autoStaticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  withAutoStaticFunctionValueCallback(
    ctx: ctx,
    function: function,
    thisObject: thisObject
  ) { functionDefinition, context, thisValue in
    autoStaticFunctionCallCallbackValue(
      functionDefinition: functionDefinition,
      context: context,
      thisValue: thisValue,
      argumentCount: Int(argumentCount),
      arguments: arguments,
      ctx: ctx,
      exception: exception
    )
  }
}

private func installAutoDynamicCallbacks(
  _ definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  if definition.getProperty != nil {
    cls.getProperty = { ctx, object, propertyName, exception in
      withAutoDynamicPropertyValueCallback(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        autoDynamicGetPropertyCallbackValue(
          definition: definition,
          context: context,
          thisValue: thisValue,
          key: key,
          ctx: ctx,
          exception: exception
        )
      }
    }
  }

  if definition.setProperty != nil {
    cls.setProperty = { ctx, object, propertyName, value, exception in
      guard let value else {
        return false
      }
      return withAutoDynamicPropertyBoolCallback(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        let newValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: value, ctx: context)
        return autoDynamicSetPropertyCallbackResult(
          definition: definition,
          context: context,
          thisValue: thisValue,
          key: key,
          newValue: newValue,
          exception: exception
        )
      }
    }
  }

  if definition.hasProperty != nil {
    cls.hasProperty = { ctx, object, propertyName in
      withAutoDynamicPropertyBoolCallback(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        autoDynamicHasPropertyCallbackResult(
          definition: definition,
          context: context,
          thisValue: thisValue,
          key: key
        )
      }
    }
  }

  if definition.deleteProperty != nil {
    cls.deleteProperty = { ctx, object, propertyName, exception in
      withAutoDynamicPropertyBoolCallback(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        autoDynamicDeletePropertyCallbackResult(
          definition: definition,
          context: context,
          thisValue: thisValue,
          key: key
        )
      }
    }
  }
}

private func installAutoStaticValueMembers(
  _ definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  backing: JSClassAutoNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !definition.staticValues.isEmpty else {
    return
  }

  backing.staticValueNames = definition.staticValues.map { $0.name.utf8CString }
  backing.staticValues = []
  backing.staticValues.reserveCapacity(definition.staticValues.count + 1)
  for (index, value) in definition.staticValues.enumerated() {
    var staticValue = JavaScriptCore.JSStaticValue()
    backing.staticValueNames[index].withUnsafeBufferPointer {
      staticValue.name = $0.baseAddress
    }
    staticValue.getProperty = autoStaticValueGetPropertyCallback
    staticValue.setProperty = autoStaticValueSetPropertyCallback
    staticValue.attributes = value.attributes.rawValue
    backing.staticValues.append(staticValue)
  }
  backing.staticValues.append(JavaScriptCore.JSStaticValue())
  backing.staticValues.withUnsafeBufferPointer {
    cls.staticValues = $0.baseAddress
  }
}

private func installAutoStaticFunctionMembers(
  _ definition: SwiftJavaScript.JSClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  backing: JSClassAutoNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !definition.staticFunctions.isEmpty else {
    return
  }

  backing.staticFunctionNames = definition.staticFunctions.map { $0.name.utf8CString }
  backing.staticFunctions = []
  backing.staticFunctions.reserveCapacity(definition.staticFunctions.count + 1)
  for (index, function) in definition.staticFunctions.enumerated() {
    var staticFunction = JavaScriptCore.JSStaticFunction()
    backing.staticFunctionNames[index].withUnsafeBufferPointer {
      staticFunction.name = $0.baseAddress
    }
    staticFunction.callAsFunction = autoStaticFunctionCallAsFunctionCallback
    staticFunction.attributes = function.attributes.rawValue
    backing.staticFunctions.append(staticFunction)
  }
  backing.staticFunctions.append(JavaScriptCore.JSStaticFunction())
  backing.staticFunctions.withUnsafeBufferPointer {
    cls.staticFunctions = $0.baseAddress
  }
}

private func autoNativeDefinition(backing: JSClassAutoNativeClassBacking)
  -> JavaScriptCore.JSClassDefinition
{
  var cls = JavaScriptCoreEngine.emptyClassDefinition
  cls.version = backing.definition.version
  cls.attributes = backing.definition.attributes.rawValue
  cls.parentClass = backing.definition.parentClass?.ref
  cls.initialize = autoClassInitializeCallback
  cls.finalize = autoClassFinalizeCallback

  installAutoStaticValueMembers(backing.definition, backing: backing, into: &cls)
  installAutoStaticFunctionMembers(backing.definition, backing: backing, into: &cls)

  installAutoDynamicCallbacks(backing.definition, into: &cls)

  return cls
}
