import Foundation
import JavaScriptCore

private typealias JSClassAutoNativeClassBacking = SwiftJavaScript.JSClassAutoNativeClassBacking<
  SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine,
    JSClass,
    JSPropertyNameAccumulatorRef
  >,
  JavaScriptCore.JSStaticValue,
  JavaScriptCore.JSStaticFunction
>

private typealias JSClassAutoObjectStorage = SwiftJavaScript.JSClassAutoObjectStorage<
  SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine,
    JSClass,
    JSPropertyNameAccumulatorRef
  >
>

private let jsClassCacheRegistry = SwiftJavaScript.JSClassCacheRegistry<ObjectIdentifier, JSClass>()

private func javaScriptCorePrivateData(
  from value: JSValueHandle<JavaScriptCoreEngine>,
  in context: JavaScriptCoreContextHandle
) -> JSResult<UnsafeMutableRawPointer?> {
  var exception: JSValueRef?
  guard let objectRef = JSValueToObject(context.ref, value.ref, &exception) else {
    return .exception(nil)
  }
  return .value(JSObjectGetPrivate(objectRef))
}

private func makeJavaScriptCoreObjectResultHandle(
  of jsClass: JSClassRef,
  privateData: UnsafeMutableRawPointer?,
  in context: JavaScriptCoreContextHandle
) -> JSResult<JSValueHandle<JavaScriptCoreEngine>> {
  guard let objectRef = JSObjectMake(context.ref, jsClass, privateData) else {
    let exception = JavaScriptCoreValueHandle(
      ref: JSValueMakeUndefined(context.ref)!,
      contextRef: context.ref
    )
    return .exception(exception)
  }
  return .value(JavaScriptCoreValueHandle(ref: objectRef, contextRef: context.ref))
}

extension JSClassValueConvertible
where
  Engine == JavaScriptCoreEngine,
  ParentClass == JSClass,
  PropertyNameAccumulator == JSPropertyNameAccumulatorRef,
  ClassDefinition == SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine,
    JSClass,
    JSPropertyNameAccumulatorRef
  >
{
  public static var jsClass: JSClass {
    let key = ObjectIdentifier(Self.self)
    return jsClassCacheRegistry.value(for: key) {
      Self.makeAutoJSClass()
    }
  }

  fileprivate static func makeAutoJSClass() -> JSClass {
    let definition = Self.autoClassDefinition()
    let backing: JSClassAutoNativeClassBacking = Self.autoNativeClassBacking(
      lookup: javaScriptCoreClassDefinitionLookup()
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
    do {
      return try tryDecode(value, in: context)
    } catch {
      fatalError("\(Self.self).decode(_:in:) failed: \(error)")
    }
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing SwiftJavaScript.JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self {
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    let jscValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(
      handleValue: unsafeBitCast(value.retainHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self)
    )
    let jscContext = JSInstantContext<JavaScriptCoreEngine>(
      handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
    )
    return try tryDecode(jscValue, in: jscContext)
  }

  public static func tryEncode<E: JSEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> SwiftJavaScript.JSValue<E> {
    precondition(
      E.self == JavaScriptCoreEngine.self,
      "This conversion path only supports JavaScriptCoreEngine"
    )
    let jscContext = JSInstantContext<JavaScriptCoreEngine>(
      handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
    )
    let encoded = try tryEncode(value, in: jscContext)
    let handle = unsafeBitCast(encoded.takeHandle(), to: JSValueHandle<E>.self)
    return SwiftJavaScript.JSValue<E>(handleValue: handle)
  }

  public static func tryDecode(
    _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> Self {
    guard value.isObject(in: context) else {
      throw .typeMismatch(expected: "object", actual: value.type(in: context))
    }
    let privateData: UnsafeMutableRawPointer?
    switch javaScriptCorePrivateData(
      from: value.borrowHandle(),
      in: context.driverContextHandle
    ) {
    case .exception:
      throw .codable("\(Self.self) could not be converted to JSObjectRef")
    case .value(let data):
      privateData = data
    }

    guard let privateData else {
      throw .codable("\(Self.self) does not have a Swift instance backing")
    }

    let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
    guard let instance = storage.typedInstance(as: Self.self) else {
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
    let storage = Self.autoObjectStorage(
      instance: value,
      lookup: javaScriptCoreClassDefinitionLookup()
    )
    let data = Unmanaged.passRetained(storage).toOpaque()

    switch makeJavaScriptCoreObjectResultHandle(
      of: Self.jsClass.ref,
      privateData: data,
      in: context.driverContextHandle
    ) {
    case .exception:
      _ = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(data).takeRetainedValue()
      throw .codable("Failed to create JS object for \(Self.self)")
    case .value(let object):
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
  ) throws(JSValueConversionError) -> T
  where
    T.Engine == JavaScriptCoreEngine, T.ParentClass == JSClass,
    T.PropertyNameAccumulator == JSPropertyNameAccumulatorRef
  {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: isolated SwiftJavaScript.JSContext<JavaScriptCoreEngine> = #isolation
  ) throws(JSValueConversionError) -> T
  where
    T.Engine == JavaScriptCoreEngine, T.ParentClass == JSClass,
    T.PropertyNameAccumulator == JSPropertyNameAccumulatorRef
  {
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
  guard let privateData = JSObjectGetPrivate(object) else {
    return nil
  }
  let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
  return (storage, privateData)
}

private func withAutoDynamicPropertyCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSEngineClassDefinition<
      JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
    >, borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, String
  ) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassStorageRecord(from: object)?.storage.definition
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

private func autoDynamicGetPropertyCallbackValue(
  definition: SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  key: String,
  ctx: JSContextRef?,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
  return javaScriptCoreCallbackReturnValue(
    definition.dynamicPropertyValue(
      in: context,
      on: thisValue,
      forKey: key
    ).toPrivateResult(),
    in: ctx,
    exception: exception
  )
}

private func autoDynamicSetPropertyCallbackResult(
  definition: SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef
  >,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  key: String,
  newValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  if let error = definition.setDynamicPropertyException(
    in: context,
    on: thisValue,
    forKey: key,
    to: newValue
  ) {
    let privateResult = JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>.exception(error)
      .toPrivateResult()
    guard case .exception(let errorRef) = privateResult else {
      return true
    }
    return javaScriptCoreCallbackSucceeded(
      exceptionValue: errorRef,
      exception: exception
    )
  }
  return true
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
    let definition = autoClassStorageRecord(from: object)?.storage.definition
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
      resolvingParentDefinition: resolveJavaScriptCoreParentClassDefinition
    )
  else {
    return nil
  }

  return withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
    body(valueDefinition, context, thisValue)
  }
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
    let definition = autoClassStorageRecord(from: thisObject)?.storage.definition
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
        resolvingParentDefinition: resolveJavaScriptCoreParentClassDefinition
      )
    else {
      return nil
    }
    return body(functionDefinition, context, thisValue)
  }
}

private func autoStaticSetPropertyCallbackResult(
  valueDefinition: SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
  context: borrowing JSInstantContext<JavaScriptCoreEngine>,
  thisValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  newValue: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  javaScriptCoreCallbackSucceeded(
    exceptionValue: valueDefinition.setPropertyException(
      in: context,
      on: thisValue,
      to: newValue
    )?.callbackRef(),
    exception: exception
  )
}

private let autoStaticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  let value = withAutoStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    javaScriptCoreCallbackReturnValue(
      valueDefinition.propertyValue(in: context, on: thisValue).toPrivateResult(),
      in: ctx,
      exception: exception
    )
  }
  return value ?? JSValueMakeUndefined(ctx)
}

private let autoStaticValueSetPropertyCallback: JSObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let value else {
    return false
  }
  let didSet = withAutoStaticValueCallbackInput(
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
  return didSet ?? false
}

private let autoStaticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  let value = withAutoStaticFunctionCallbackInput(
    ctx: ctx,
    function: function,
    thisObject: thisObject
  ) { functionDefinition, context, thisValue in
    let result = withJavaScriptCoreArguments(arguments, count: Int(argumentCount)) { args in
      functionDefinition.callResult(in: context, on: thisValue, with: args).toPrivateResult()
    }
    return javaScriptCoreCallbackReturnValue(
      result,
      in: ctx,
      exception: exception
    )
  }
  return value ?? JSValueMakeUndefined(ctx)
}

private func installAutoDynamicCallbacks(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  if callbacks.hasDynamicPropertyGetter {
    cls.getProperty = { ctx, object, propertyName, exception in
      let value = withAutoDynamicPropertyCallbackInput(
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
      return value ?? JSValueMakeUndefined(ctx)
    }
  }

  if callbacks.hasDynamicPropertySetter {
    cls.setProperty = { ctx, object, propertyName, value, exception in
      guard let value else {
        return false
      }
      let didSet = withAutoDynamicPropertyCallbackInput(
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
      return didSet ?? false
    }
  }

  if callbacks.hasDynamicPropertyHas {
    cls.hasProperty = { ctx, object, propertyName in
      let hasProperty = withAutoDynamicPropertyCallbackInput(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        definition.hasDynamicProperty(in: context, on: thisValue, forKey: key)
      }
      return hasProperty ?? false
    }
  }

  if callbacks.hasDynamicPropertyDelete {
    cls.deleteProperty = { ctx, object, propertyName, exception in
      let didDelete = withAutoDynamicPropertyCallbackInput(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        definition.deleteDynamicProperty(in: context, on: thisValue, forKey: key)
      }
      return didDelete ?? false
    }
  }
}

private func installAutoStaticValueMembers(
  _ staticValues: [SwiftJavaScript.JSClassStaticValueDefinition],
  backing: JSClassAutoNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !staticValues.isEmpty else {
    return
  }

  backing.staticValueNames = staticValues.map { $0.name.utf8CString }
  backing.staticValues = []
  backing.staticValues.reserveCapacity(staticValues.count + 1)
  for (index, value) in staticValues.enumerated() {
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
  _ staticFunctions: [SwiftJavaScript.JSClassStaticFunctionDefinition],
  backing: JSClassAutoNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !staticFunctions.isEmpty else {
    return
  }

  backing.staticFunctionNames = staticFunctions.map { $0.name.utf8CString }
  backing.staticFunctions = []
  backing.staticFunctions.reserveCapacity(staticFunctions.count + 1)
  for (index, function) in staticFunctions.enumerated() {
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
  let definition = backing.definition.classDefinition
  let callbacks = backing.definition.callbackInstallationPlan
  var cls = JavaScriptCore.kJSClassDefinitionEmpty
  cls.version = definition.version
  cls.attributes = definition.attributes.rawValue
  cls.parentClass = definition.parentClass?.ref
  cls.initialize = autoClassInitializeCallback
  cls.finalize = autoClassFinalizeCallback

  installAutoStaticValueMembers(definition.staticValues, backing: backing, into: &cls)
  installAutoStaticFunctionMembers(definition.staticFunctions, backing: backing, into: &cls)

  installAutoDynamicCallbacks(callbacks, into: &cls)

  return cls
}
