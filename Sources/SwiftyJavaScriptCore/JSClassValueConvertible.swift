import Foundation
import JavaScriptCore

private typealias JSClassAutoNativeClassBacking = SwiftJavaScript.JSClassAutoNativeClassBacking<
  SwiftJavaScript.JSEngineClassDefinition<
    JSCContext,
    JSCClassParentDescriptor,
    JSPropertyNameAccumulatorRef
  >,
  JavaScriptCore.JSStaticValue,
  JavaScriptCore.JSStaticFunction
>

private typealias JSClassAutoObjectStorage = SwiftJavaScript.JSClassAutoObjectStorage<
  SwiftJavaScript.JSEngineClassDefinition<
    JSCContext,
    JSCClassParentDescriptor,
    JSPropertyNameAccumulatorRef
  >
>

public typealias JSCClassParentDescriptor = SwiftJavaScript.JSClassParentDescriptor<
  JSCContext,
  JSPropertyNameAccumulatorRef
>

public typealias JSCStaticValue = SwiftJavaScript.JSStaticValue<JSCContext>

public typealias JSCStaticFunction = SwiftJavaScript.JSStaticFunction<JSCContext>

public typealias JSCAutoClassDefinition = SwiftJavaScript.JSEngineClassDefinition<
  JSCContext,
  JSCClassParentDescriptor,
  JSPropertyNameAccumulatorRef
>

private struct JavaScriptCoreClassCacheKey: Hashable, Sendable {
  let identity: ObjectIdentifier
  let runtime: UInt
}

private let jsClassRegistry = SwiftJavaScript.JSClassMapRegistry<
  JavaScriptCoreClassCacheKey, JSCClass
>()

private func javaScriptCorePrivateData(
  from value: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<UnsafeMutableRawPointer?> {
  var exception: JSValueRef?
  guard let objectRef = JSValueToObject(context, value, &exception) else {
    return .exception(nil)
  }
  return .value(JSObjectGetPrivate(objectRef))
}

private func makeJavaScriptCoreObjectResultHandle(
  of jsClass: JSClassRef,
  privateData: UnsafeMutableRawPointer?,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef> {
  guard let objectRef = JSObjectMake(context, jsClass, privateData) else {
    let exception = JSValueMakeUndefined(context)!
    return .exception(exception)
  }
  return .value(objectRef)
}

private func makeJavaScriptCoreAutoJSClass(
  definition: JSCAutoClassDefinition,
  in context: borrowing JSCInstantContext
) -> JSCClass {
  let backing = JSClassAutoNativeClassBacking(
    definition: definition,
    lookup: SwiftJavaScript.JSClassDefinitionLookup {
      $0.definition()
    }
  )
  let nativeDefinition = autoNativeDefinition(backing: backing, in: context)
  return JSCClass(
    nativeDefinition: nativeDefinition,
    retainedBacking: backing
  )
}

extension JSCInstantContext {
  public func makeClass(
    definition: JSCAutoClassDefinition,
    identity: ObjectIdentifier
  ) -> JSCClass {
    guard let runtime = javaScriptCoreContextGroupBits(for: contextRef) else {
      preconditionFailure("JavaScriptCore context has no context group")
    }
    let key = JavaScriptCoreClassCacheKey(identity: identity, runtime: runtime)
    return jsClassRegistry.value(forKey: key) {
      makeJavaScriptCoreAutoJSClass(definition: definition, in: self)
    }
  }

  public func makeHostObject(
    of jsClass: JSCClass,
    privateData: UnsafeMutableRawPointer
  ) -> JSCValue? {
    switch makeJavaScriptCoreObjectResultHandle(
      of: jsClass.ref,
      privateData: privateData,
      in: contextRef
    ) {
    case .value(let object):
      // The host object belongs to the encoding scope's synchronous window:
      // its creation reference is settled when that scope drains. Anchoring
      // on the context default scope instead would keep the object alive (and
      // its finalizer unfired) until the context dies, even after JavaScript
      // drops every reference to it.
      return adoptCreatedHandle(object)
    case .exception:
      // JavaScriptCore is GC-managed: the failure path owns nothing to
      // settle, and the private data stays with the caller.
      return nil
    }
  }

  public func hostObjectPrivateData(of value: borrowing JSCValue) -> UnsafeMutableRawPointer? {
    switch javaScriptCorePrivateData(
      from: value.ref, in: contextRef
    ) {
    case .value(let data):
      return data
    case .exception:
      return nil
    }
  }
}

// The value-level convenience entries live on the concrete value view (S11):
// the generic class conversion is engine-bound, so the caller's value already
// names the engine and no handle cast is involved.

extension JSCValue {
  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: borrowing JSCInstantContext
  ) throws(JSValueConversionError) -> T
  where
    T.Context == JSCContext, T.ParentClass == JSCClassParentDescriptor,
    T.PropertyNameAccumulator == JSPropertyNameAccumulatorRef
  {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: isolated JSCContext = #isolation
  ) throws(JSValueConversionError) -> T
  where
    T.Context == JSCContext, T.ParentClass == JSCClassParentDescriptor,
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
    JSCAutoClassDefinition, borrowing JSCInstantContext,
    borrowing JSCValue, String
  ) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassStorageRecord(from: object)?.storage.definition
  else {
    return nil
  }

  let key = javaScriptCoreString(propertyName)
  return withRememberedClassObjectValue(ctx, object: object) { context, thisValue in
    body(definition, context, thisValue, key)
  }
}

private func autoDynamicGetPropertyValue(
  definition: JSCAutoClassDefinition,
  context: borrowing JSCInstantContext,
  thisValue: borrowing JSCValue,
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
  definition: JSCAutoClassDefinition,
  context: borrowing JSCInstantContext,
  thisValue: borrowing JSCValue,
  key: String,
  newValue: borrowing JSCValue,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  if let error = definition.setDynamicPropertyException(
    in: context,
    on: thisValue,
    forKey: key,
    to: newValue
  ) {
    let privateResult = JSResult<JSCValue>.exception(error)
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
    SwiftJavaScript.JSStaticValue<JSCContext>,
    borrowing JSCInstantContext,
    borrowing JSCValue
  ) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassStorageRecord(from: object)?.storage.definition
  else {
    return nil
  }

  let name = javaScriptCoreString(propertyName)
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
    SwiftJavaScript.JSStaticFunction<JSCContext>,
    borrowing JSCInstantContext,
    borrowing JSCValue
  ) ->
    R
) -> R? {
  guard let ctx, let function, let thisObject,
    let definition = autoClassStorageRecord(from: thisObject)?.storage.definition
  else {
    return nil
  }

  return withRememberedClassObjectValue(ctx, object: thisObject) { context, thisValue in
    let functionValue = JSCValue(ref: function, in: context)
    let functionName: String
    switch functionValue.getProperty("name", in: context) {
    case .value(let name):
      functionName = name.toString()
    case .exception:
      return nil
    }
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
  valueDefinition: SwiftJavaScript.JSStaticValue<JSCContext>,
  context: borrowing JSCInstantContext,
  thisValue: borrowing JSCValue,
  newValue: borrowing JSCValue,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  let failure = valueDefinition.setPropertyException(
    in: context,
    on: thisValue,
    to: newValue
  )
  let exceptionRef: JSValueRef?
  if let failure {
    exceptionRef = failure.ref
  } else {
    exceptionRef = nil
  }
  return javaScriptCoreCallbackSucceeded(
    exceptionValue: exceptionRef,
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
    let newValue = JSCValue(ref: value, in: context)
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
        autoDynamicGetPropertyValue(
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
        let newValue = JSCValue(ref: value, in: context)
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
  in context: borrowing JSCInstantContext
)
  -> JavaScriptCore.JSClassDefinition
{
  let definition = backing.definition.classDefinition
  let callbacks = backing.definition.callbackInstallationPlan
  var cls = JavaScriptCore.kJSClassDefinitionEmpty
  cls.version = definition.version
  cls.attributes = definition.attributes.rawValue
  cls.parentClass = definition.parentClass?.jsClass(in: context).ref
  cls.initialize = autoClassInitializeCallback
  cls.finalize = autoClassFinalizeCallback

  installAutoStaticValueMembers(definition.staticValues, backing: backing, into: &cls)
  installAutoStaticFunctionMembers(definition.staticFunctions, backing: backing, into: &cls)

  installAutoDynamicCallbacks(callbacks, into: &cls)

  return cls
}
