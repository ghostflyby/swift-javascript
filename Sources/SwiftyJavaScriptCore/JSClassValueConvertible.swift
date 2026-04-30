import Foundation
import JavaScriptCore

private typealias JSClassAutoNativeClassBacking = SwiftJavaScript.JSClassAutoNativeClassBacking<
  SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine,
    JavaScriptCoreClassParentDescriptor,
    JSPropertyNameAccumulatorRef
  >,
  JavaScriptCore.JSStaticValue,
  JavaScriptCore.JSStaticFunction
>

private typealias JSClassAutoObjectStorage = SwiftJavaScript.JSClassAutoObjectStorage<
  SwiftJavaScript.JSEngineClassDefinition<
    JavaScriptCoreEngine,
    JavaScriptCoreClassParentDescriptor,
    JSPropertyNameAccumulatorRef
  >
>

public typealias JavaScriptCoreClassParentDescriptor = SwiftJavaScript.JSClassParentDescriptor<
  JavaScriptCoreEngine,
  JSPropertyNameAccumulatorRef
>

public typealias JavaScriptCoreAutoClassDefinition = SwiftJavaScript.JSEngineClassDefinition<
  JavaScriptCoreEngine,
  JavaScriptCoreClassParentDescriptor,
  JSPropertyNameAccumulatorRef
>

private let jsClassRegistry = SwiftJavaScript.JSClassMapRegistry<ObjectIdentifier, JSClass>()
private let javaScriptCoreCompatibilityClassRuntime = JavaScriptCoreRuntimeHandle()

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

private func makeJavaScriptCoreAutoJSClass(
  definition: JavaScriptCoreAutoClassDefinition,
  in runtime: JavaScriptCoreRuntimeHandle
) -> JSClass {
  let backing = JSClassAutoNativeClassBacking(
    definition: definition,
    lookup: SwiftJavaScript.JSClassDefinitionLookup {
      $0.definition()
    }
  )
  let nativeDefinition = autoNativeDefinition(backing: backing, in: runtime)
  return JSClass(
    nativeDefinition: nativeDefinition,
    retainedBacking: backing
  )
}

extension JavaScriptCoreEngine: SwiftJavaScript.JSEngineClassBridgeDriver {
  public typealias ClassPropertyNameAccumulator = JSPropertyNameAccumulatorRef

  public static func makeClass(
    definition: JavaScriptCoreAutoClassDefinition,
    in runtime: JavaScriptCoreRuntimeHandle
  ) -> JSClass {
    makeJavaScriptCoreAutoJSClass(definition: definition, in: runtime)
  }

  public static func runtimeHandle(
    for context: JavaScriptCoreContextHandle
  ) -> JavaScriptCoreRuntimeHandle? {
    JavaScriptCoreRuntimeHandle(borrowing: JSContextGetGroup(context.ref))
  }

  public static func makeClassObjectResultHandle(
    of jsClass: JSClass,
    privateData: UnsafeMutableRawPointer,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    makeJavaScriptCoreObjectResultHandle(
      of: jsClass.ref,
      privateData: privateData,
      in: context
    )
  }

  public static func classObjectPrivateData(
    from value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<UnsafeMutableRawPointer?>? {
    javaScriptCorePrivateData(from: value, in: context)
  }

}

extension JSClassValueConvertible
where
  Engine == JavaScriptCoreEngine,
  ParentClass == JavaScriptCoreClassParentDescriptor,
  PropertyNameAccumulator == JSPropertyNameAccumulatorRef,
  ClassDefinition == JavaScriptCoreAutoClassDefinition
{
  public static var jsClass: JSClass {
    let key = ObjectIdentifier(Self.self)
    return jsClassRegistry.value(forKey: key, orInsert: Self.makeAutoJSClass)
  }

  fileprivate static func makeAutoJSClass() -> JSClass {
    let backing: JSClassAutoNativeClassBacking = Self.autoNativeClassBacking(
      lookup: SwiftJavaScript.JSClassDefinitionLookup {
        $0.definition()
      }
    )
    let nativeDefinition = autoNativeDefinition(
      backing: backing,
      in: javaScriptCoreCompatibilityClassRuntime
    )
    return JSClass(
      nativeDefinition: nativeDefinition,
      retainedBacking: backing
    )
  }
}

extension SwiftJavaScript.JSValue where E == JavaScriptCoreEngine {
  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: borrowing JSInstantContext<JavaScriptCoreEngine>
  ) throws(JSValueConversionError) -> T
  where
    T.Engine == JavaScriptCoreEngine, T.ParentClass == JavaScriptCoreClassParentDescriptor,
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
    T.Engine == JavaScriptCoreEngine, T.ParentClass == JavaScriptCoreClassParentDescriptor,
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
    JavaScriptCoreAutoClassDefinition, borrowing JSInstantContext<JavaScriptCoreEngine>,
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
  definition: JavaScriptCoreAutoClassDefinition,
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
  definition: JavaScriptCoreAutoClassDefinition,
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
      resolvingParentDefinition: { $0.definition() }
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
        resolvingParentDefinition: { $0.definition() }
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

private func autoNativeDefinition(
  backing: JSClassAutoNativeClassBacking,
  in runtime: JavaScriptCoreRuntimeHandle
)
  -> JavaScriptCore.JSClassDefinition
{
  let definition = backing.definition.classDefinition
  let callbacks = backing.definition.callbackInstallationPlan
  var cls = JavaScriptCore.kJSClassDefinitionEmpty
  cls.version = definition.version
  cls.attributes = definition.attributes.rawValue
  cls.parentClass = definition.parentClass?.jsClass(in: runtime).ref
  cls.initialize = autoClassInitializeCallback
  cls.finalize = autoClassFinalizeCallback

  installAutoStaticValueMembers(definition.staticValues, backing: backing, into: &cls)
  installAutoStaticFunctionMembers(definition.staticFunctions, backing: backing, into: &cls)

  installAutoDynamicCallbacks(callbacks, into: &cls)

  return cls
}
