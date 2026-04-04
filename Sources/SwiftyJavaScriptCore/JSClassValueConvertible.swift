import Foundation

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
  let definition: JSClassDefinition
  let usesManagedParent: Bool
  var staticValueNames: [ContiguousArray<CChar>] = []
  var staticValues: [JavaScriptCoreStaticValue] = []
  var staticFunctionNames: [ContiguousArray<CChar>] = []
  var staticFunctions: [JavaScriptCoreStaticFunction] = []

  init(definition: JSClassDefinition, usesManagedParent: Bool) {
    self.definition = definition
    self.usesManagedParent = usesManagedParent
  }
}

final class JSClassAutoObjectStorage {
  let definition: JSClassDefinition
  let instance: AnyObject
  let finalizeDepth: Int

  init(definition: JSClassDefinition, instance: AnyObject, finalizeDepth: Int) {
    self.definition = definition
    self.instance = instance
    self.finalizeDepth = finalizeDepth
  }
}

private let jsClassCacheRegistry = JSClassCacheRegistry()

public protocol JSClassValueConvertible: AnyObject, JSValueEncodable {
  static var jsClassDefinition: JSClassDefinition { get }
  static func decode(_ value: borrowing JSValue, in context: borrowing JSInstantContext) -> Self
  static func tryDecode(
    _ value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> Self
  static func encode(_ value: Self, in context: borrowing JSInstantContext) -> JSValue
  static func tryEncode(
    _ value: Self,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> JSValue
}

public enum JSClassValueConverter<T: JSClassValueConvertible>: JSValueConverter {
  public typealias SwiftType = T

  public static func decode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) -> T {
    let jscValue = _bridgeJavaScriptCoreValue(value)
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return decode(jscValue, in: jscContext)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSEngineValue<E>,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    let jscValue = _bridgeJavaScriptCoreValue(value)
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return try tryDecode(jscValue, in: jscContext)
  }

  public static func encode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return _asGenericValue(encode(value, in: jscContext))
  }

  public static func tryEncode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> JSEngineValue<E> {
    let jscContext = _bridgeJavaScriptCoreContext(context)
    let encoded = try tryEncode(value, in: jscContext)
    return _asGenericValue(encoded)
  }

  public static func decode(_ value: borrowing JSValue, in context: borrowing JSInstantContext)
    -> T
  {
    T.decode(value, in: context)
  }

  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode(_ value: T, in context: borrowing JSInstantContext) -> JSValue {
    T.encode(value, in: context)
  }

  public static func tryEncode(
    _ value: T,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> JSValue {
    try T.tryEncode(value, in: context)
  }
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

  public static func decode(_ value: borrowing JSValue, in context: borrowing JSInstantContext)
    -> Self
  {
    do {
      return try tryDecode(value, in: context)
    } catch {
      fatalError("\(Self.self).decode(_:in:) failed: \(error)")
    }
  }

  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: borrowing JSInstantContext
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
      throw .codable("\(Self.self) could not be converted to JavaScriptCoreObjectRef")
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

  public static func encode(_ value: Self, in context: borrowing JSInstantContext) -> JSValue {
    do {
      return try tryEncode(value, in: context)
    } catch {
      return JSValue(undefinedIn: context)
    }
  }

  public static func tryEncode(
    _ value: Self,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> JSValue {
    let definition = Self.jsClassDefinition
    let storage = JSClassAutoObjectStorage(
      definition: definition,
      instance: value,
      finalizeDepth: exportedDefinitionCount(definition)
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
      return JSValue(handleValue: object)
    }
  }

  public func toJSValue<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) -> JSEngineValue<E> {
    let jscContext = _bridgeJavaScriptCoreContext(context)
    return _asGenericValue(Self.encode(self, in: jscContext))
  }

  public func tryEncode<E: JSEngine>(
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> JSEngineValue<E> {
    let jscContext = _bridgeJavaScriptCoreContext(context)
    let encoded = try Self.tryEncode(self, in: jscContext)
    return _asGenericValue(encoded)
  }
}

extension JSValue {
  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try T.tryDecode(self, in: callbackContext)
    }
  }
}

private let autoClassInitializeCallback: JavaScriptCoreObjectInitializeCallback = { ctx, object in
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

private let autoClassFinalizeCallback: JavaScriptCoreObjectFinalizeCallback = { object in
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

private func autoClassStorageRecord(from object: JavaScriptCoreObjectRef)
  -> (storage: JSClassAutoObjectStorage, privateData: UnsafeMutableRawPointer)?
{
  guard let privateData = JavaScriptCoreEngine.privateData(from: object) else {
    return nil
  }
  let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
  return (storage, privateData)
}

private func autoClassStorage(from object: JavaScriptCoreObjectRef) -> JSClassAutoObjectStorage? {
  autoClassStorageRecord(from: object)?.storage
}

private func autoClassDefinition(from object: JavaScriptCoreObjectRef) -> JSClassDefinition? {
  autoClassStorage(from: object)?.definition
}

private func autoCallbackValueOrUndefined(
  _ value: JavaScriptCoreValueRef?, in ctx: JavaScriptCoreContextRef?
)
  -> JavaScriptCoreValueRef?
{
  value ?? JavaScriptCoreEngine.undefinedValue(in: ctx)
}

private func autoCallbackValueOrUndefined(
  _ value: JavaScriptCoreValueRef??, in ctx: JavaScriptCoreContextRef?
)
  -> JavaScriptCoreValueRef?
{
  value ?? JavaScriptCoreEngine.undefinedValue(in: ctx)
}

private func autoCallbackSucceededOrFalse(_ value: Bool?) -> Bool {
  value ?? false
}

private func withAutoDynamicPropertyCallbackInput<R>(
  ctx: JavaScriptCoreContextRef?,
  object: JavaScriptCoreObjectRef?,
  propertyName: JavaScriptCoreStringRef?,
  _ body: (JSClassDefinition, borrowing JSInstantContext, borrowing JSValue, String) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return nil
  }

  let key = String(jsStringRef: propertyName)
  return withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
    body(definition, context, thisValue, key)
  }
}

private func withAutoDynamicPropertyValueCallback(
  ctx: JavaScriptCoreContextRef?,
  object: JavaScriptCoreObjectRef?,
  propertyName: JavaScriptCoreStringRef?,
  _ body: (JSClassDefinition, borrowing JSInstantContext, borrowing JSValue, String) ->
    JavaScriptCoreValueRef?
) -> JavaScriptCoreValueRef? {
  let value = withAutoDynamicPropertyCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName,
    body
  )
  return autoCallbackValueOrUndefined(value, in: ctx)
}

private func withAutoDynamicPropertyBoolCallback(
  ctx: JavaScriptCoreContextRef?,
  object: JavaScriptCoreObjectRef?,
  propertyName: JavaScriptCoreStringRef?,
  _ body: (JSClassDefinition, borrowing JSInstantContext, borrowing JSValue, String) -> Bool
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
  definition: JSClassDefinition,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  key: String,
  ctx: JavaScriptCoreContextRef?,
  exception: UnsafeMutablePointer<JavaScriptCoreValueRef?>?
) -> JavaScriptCoreValueRef? {
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
  definition: JSClassDefinition,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  key: String,
  newValue: borrowing JSValue,
  exception: UnsafeMutablePointer<JavaScriptCoreValueRef?>?
) -> Bool {
  guard let setProperty = definition.setProperty else {
    return true
  }
  if let error = setProperty(context, thisValue, key, newValue) {
    let privateResult = JSResult.exception(error).toPrivateResult()
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
  definition: JSClassDefinition,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  key: String
) -> Bool {
  definition.hasProperty?(context, thisValue, key) ?? false
}

private func autoDynamicDeletePropertyCallbackResult(
  definition: JSClassDefinition,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  key: String
) -> Bool {
  definition.deleteProperty?(context, thisValue, key) ?? false
}

private func withAutoStaticValueCallbackInput<R>(
  ctx: JavaScriptCoreContextRef?,
  object: JavaScriptCoreObjectRef?,
  propertyName: JavaScriptCoreStringRef?,
  _ body: (JSStaticValue, borrowing JSInstantContext, borrowing JSValue) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return nil
  }

  let name = String(jsStringRef: propertyName)
  guard let valueDefinition = inheritedStaticValue(named: name, from: definition) else {
    return nil
  }

  return withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
    body(valueDefinition, context, thisValue)
  }
}

private func withAutoStaticValuePropertyCallback(
  ctx: JavaScriptCoreContextRef?,
  object: JavaScriptCoreObjectRef?,
  propertyName: JavaScriptCoreStringRef?,
  _ body: (JSStaticValue, borrowing JSInstantContext, borrowing JSValue) -> JavaScriptCoreValueRef?
) -> JavaScriptCoreValueRef? {
  let value = withAutoStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName,
    body
  )
  return autoCallbackValueOrUndefined(value, in: ctx)
}

private func withAutoStaticValueBooleanCallback(
  ctx: JavaScriptCoreContextRef?,
  object: JavaScriptCoreObjectRef?,
  propertyName: JavaScriptCoreStringRef?,
  _ body: (JSStaticValue, borrowing JSInstantContext, borrowing JSValue) -> Bool
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
  ctx: JavaScriptCoreContextRef?,
  function: JavaScriptCoreObjectRef?,
  thisObject: JavaScriptCoreObjectRef?,
  _ body: (JSStaticFunction, borrowing JSInstantContext, borrowing JSValue) -> R
) -> R? {
  guard let ctx, let function, let thisObject,
    let definition = autoClassDefinition(from: thisObject)
  else {
    return nil
  }

  return withRememberedClassObjectValue(ctx, object: thisObject) { context, thisValue in
    let functionValue = JSValue(ref: function, ctx: context)
    let functionName = functionValue.getProperty(forKey: JSStringManaged("name"), in: context)
      .toString(in: context)
    guard let functionDefinition = inheritedStaticFunction(named: functionName, from: definition)
    else {
      return nil
    }
    return body(functionDefinition, context, thisValue)
  }
}

private func withAutoStaticFunctionValueCallback(
  ctx: JavaScriptCoreContextRef?,
  function: JavaScriptCoreObjectRef?,
  thisObject: JavaScriptCoreObjectRef?,
  _ body: (JSStaticFunction, borrowing JSInstantContext, borrowing JSValue) ->
    JavaScriptCoreValueRef?
) -> JavaScriptCoreValueRef? {
  let value = withAutoStaticFunctionCallbackInput(
    ctx: ctx,
    function: function,
    thisObject: thisObject,
    body
  )
  return autoCallbackValueOrUndefined(value, in: ctx)
}

private func autoStaticGetPropertyCallbackValue(
  valueDefinition: JSStaticValue,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  ctx: JavaScriptCoreContextRef?,
  exception: UnsafeMutablePointer<JavaScriptCoreValueRef?>?
) -> JavaScriptCoreValueRef? {
  JavaScriptCoreEngine.callbackReturnValue(
    valueDefinition.getProperty(context, thisValue).toPrivateResult(),
    in: ctx,
    exception: exception
  )
}

private func autoStaticSetPropertyCallbackResult(
  valueDefinition: JSStaticValue,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  newValue: borrowing JSValue,
  exception: UnsafeMutablePointer<JavaScriptCoreValueRef?>?
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
  functionDefinition: JSStaticFunction,
  context: borrowing JSInstantContext,
  thisValue: borrowing JSValue,
  argumentCount: Int,
  arguments: UnsafePointer<JavaScriptCoreValueRef?>?,
  ctx: JavaScriptCoreContextRef?,
  exception: UnsafeMutablePointer<JavaScriptCoreValueRef?>?
) -> JavaScriptCoreValueRef? {
  let result = JavaScriptCoreEngine.withArguments(arguments, count: argumentCount) { args in
    functionDefinition.callAsFunction(context, thisValue, args).toPrivateResult()
  }
  return JavaScriptCoreEngine.callbackReturnValue(
    result,
    in: ctx,
    exception: exception
  )
}

private let autoStaticValueGetPropertyCallback: JavaScriptCoreObjectGetPropertyCallback = {
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

private let autoStaticValueSetPropertyCallback: JavaScriptCoreObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let value else {
    return false
  }
  return withAutoStaticValueBooleanCallback(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    let newValue = JSValue(ref: value, ctx: context)
    return autoStaticSetPropertyCallbackResult(
      valueDefinition: valueDefinition,
      context: context,
      thisValue: thisValue,
      newValue: newValue,
      exception: exception
    )
  }
}

private let autoStaticFunctionCallAsFunctionCallback: JavaScriptCoreObjectCallAsFunctionCallback = {
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
  _ definition: JSClassDefinition,
  into cls: inout JavaScriptCoreClassDefinition
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
        let newValue = JSValue(ref: value, ctx: context)
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
  _ definition: JSClassDefinition,
  backing: JSClassAutoNativeClassBacking,
  into cls: inout JavaScriptCoreClassDefinition
) {
  guard !definition.staticValues.isEmpty else {
    return
  }

  backing.staticValueNames = definition.staticValues.map { $0.name.utf8CString }
  backing.staticValues = []
  backing.staticValues.reserveCapacity(definition.staticValues.count + 1)
  for (index, value) in definition.staticValues.enumerated() {
    var staticValue = JavaScriptCoreStaticValue()
    backing.staticValueNames[index].withUnsafeBufferPointer {
      staticValue.name = $0.baseAddress
    }
    staticValue.getProperty = autoStaticValueGetPropertyCallback
    staticValue.setProperty = autoStaticValueSetPropertyCallback
    staticValue.attributes = value.attributes.rawValue
    backing.staticValues.append(staticValue)
  }
  backing.staticValues.append(JavaScriptCoreStaticValue())
  backing.staticValues.withUnsafeBufferPointer {
    cls.staticValues = $0.baseAddress
  }
}

private func installAutoStaticFunctionMembers(
  _ definition: JSClassDefinition,
  backing: JSClassAutoNativeClassBacking,
  into cls: inout JavaScriptCoreClassDefinition
) {
  guard !definition.staticFunctions.isEmpty else {
    return
  }

  backing.staticFunctionNames = definition.staticFunctions.map { $0.name.utf8CString }
  backing.staticFunctions = []
  backing.staticFunctions.reserveCapacity(definition.staticFunctions.count + 1)
  for (index, function) in definition.staticFunctions.enumerated() {
    var staticFunction = JavaScriptCoreStaticFunction()
    backing.staticFunctionNames[index].withUnsafeBufferPointer {
      staticFunction.name = $0.baseAddress
    }
    staticFunction.callAsFunction = autoStaticFunctionCallAsFunctionCallback
    staticFunction.attributes = function.attributes.rawValue
    backing.staticFunctions.append(staticFunction)
  }
  backing.staticFunctions.append(JavaScriptCoreStaticFunction())
  backing.staticFunctions.withUnsafeBufferPointer {
    cls.staticFunctions = $0.baseAddress
  }
}

private func autoNativeDefinition(backing: JSClassAutoNativeClassBacking)
  -> JavaScriptCoreClassDefinition
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
