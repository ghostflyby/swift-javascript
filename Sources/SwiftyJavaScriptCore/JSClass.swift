import Foundation
import JavaScriptCore

public typealias JSClass = SwiftJavaScript.JSClass<JavaScriptCoreEngine>

public struct JavaScriptCoreClassHandle: SwiftJavaScript.JSClassManualReferenceCountedHandle,
  @unchecked Sendable
{
  public let ref: JSClassRef

  public init(ref: JSClassRef) {
    self.ref = ref
  }

  @discardableResult
  public func retainReference() -> Bool {
    JSClassRetain(ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JSClassRelease(ref)
    return true
  }
}

extension JavaScriptCoreClassHandle: Hashable {
  public static func == (lhs: JavaScriptCoreClassHandle, rhs: JavaScriptCoreClassHandle)
    -> Bool
  {
    lhs.ref == rhs.ref
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(UInt(bitPattern: ref))
  }
}

extension SwiftJavaScript.JSClassAttributes {
  public static let none = SwiftJavaScript.JSClassAttributes(
    rawValue: UInt32(kJSClassAttributeNone))
  public static let noAutomaticPrototype = SwiftJavaScript.JSClassAttributes(
    rawValue: UInt32(kJSClassAttributeNoAutomaticPrototype))
}

typealias JavaScriptCoreClassDefinitionModel = SwiftJavaScript.JSEngineClassDefinition<
  JavaScriptCoreEngine,
  JSClass,
  JSPropertyNameAccumulatorRef
>
typealias JSManualNativeClassBacking = SwiftJavaScript.JSClassManualNativeClassBacking<
  JavaScriptCore.JSStaticValue,
  JavaScriptCore.JSStaticFunction
>

extension SwiftJavaScript.JSEngineClassDefinition
where
  E == JavaScriptCoreEngine,
  ParentClass == JSClass,
  PropertyNameAccumulator == JSPropertyNameAccumulatorRef
{
  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer
  ) -> JSHostTypeDescriptor {
    hostTypeDescriptor(
      storagePolicy: storagePolicy,
      parentName: parentClass.flatMap {
        classDefinitionRegistry.get(UInt(bitPattern: $0.ref))?.className
      }
    )
  }
}

private typealias JSClassObjectContextRegistry = SwiftJavaScript.JSClassMapRegistry<
  UInt, JSContextRef
>
private typealias JavaScriptCoreClassDefinitionModelRegistry = SwiftJavaScript.JSClassMapRegistry<
  UInt,
  JavaScriptCoreClassDefinitionModel
>

private let classObjectContextRegistry = JSClassObjectContextRegistry()

private typealias JSClassObjectDefinitionRegistry = SwiftJavaScript.JSClassDefinitionDepthRegistry<
  UInt,
  JavaScriptCoreClassDefinitionModel
>
private typealias JSClassObjectFinalizeCounterRegistry =
  SwiftJavaScript.JSClassFinalizeCounterRegistry<UInt>

private let classDefinitionRegistry = JavaScriptCoreClassDefinitionModelRegistry()
private let classObjectDefinitionRegistry = JSClassObjectDefinitionRegistry()
private let classObjectFinalizeCounterRegistry = JSClassObjectFinalizeCounterRegistry()

func javaScriptCoreClassDefinitionLookup()
  -> SwiftJavaScript.JSEngineClassDefinitionLookup<
    JavaScriptCoreEngine,
    JSClass,
    JSPropertyNameAccumulatorRef
  >
{
  SwiftJavaScript.JSEngineClassDefinitionLookup {
    classDefinition(for: $0.ref)
  }
}

func makeRememberedClassCallbackContext(
  _ ctx: JSContextRef, _ object: JSObjectRef
)
  -> JSInstantContext<JavaScriptCoreEngine>
{
  rememberClassObjectContext(ctx, object)
  return JSInstantContext<JavaScriptCoreEngine>(ctx: ctx)
}

func withRememberedClassObjectValue<R>(
  _ ctx: JSContextRef,
  object: JSObjectRef,
  _ body: (
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> R
) -> R {
  let context = makeRememberedClassCallbackContext(ctx, object)
  let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
  return body(context, thisValue)
}

func withStoredClassObjectValue<R>(
  _ object: JSObjectRef,
  _ body: (
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> R
) -> R? {
  guard let objectContext = classObjectContext(object) else {
    return nil
  }
  let context = JSInstantContext<JavaScriptCoreEngine>(ctx: objectContext)
  let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
  return body(context, thisValue)
}

func classPropertyName(_ propertyName: JSStringRef?) -> String? {
  guard let propertyName else {
    return nil
  }
  return String(
    jsStringHandle: JavaScriptCoreStringHandle(ref: propertyName),
    engine: JavaScriptCoreEngine.self
  )
}

func rememberClassObjectContext(_ ctx: JSContextRef, _ object: JSObjectRef) {
  classObjectContextRegistry.set(UInt(bitPattern: object), value: ctx)
}

func classObjectContext(_ object: JSObjectRef) -> JSContextRef? {
  classObjectContextRegistry.get(UInt(bitPattern: object))
}

func removeClassObjectContext(_ object: JSObjectRef) {
  classObjectContextRegistry.remove(UInt(bitPattern: object))
}

func classDefinition(from object: JSObjectRef) -> JavaScriptCoreClassDefinitionModel? {
  classObjectDefinitionRegistry.get(UInt(bitPattern: object))
}

func classDefinition(for jsClass: JSClassRef) -> JavaScriptCoreClassDefinitionModel? {
  classDefinitionRegistry.get(UInt(bitPattern: jsClass))
}

func rememberClassObjectDefinition(
  _ object: JSObjectRef, definition: JavaScriptCoreClassDefinitionModel
) {
  classObjectDefinitionRegistry.set(
    UInt(bitPattern: object),
    definition: definition,
    depth: javaScriptCoreClassDefinitionLookup().inheritanceDepth(of: definition)
  )
}

func rememberClassObjectFinalizeCount(
  _ object: JSObjectRef, definition: JavaScriptCoreClassDefinitionModel
) {
  classObjectFinalizeCounterRegistry.setMax(
    UInt(bitPattern: object),
    count: javaScriptCoreClassDefinitionLookup().exportedDefinitionCount(of: definition)
  )
}

private func finalizeCountAfterDecrement(_ object: JSObjectRef) -> Int {
  classObjectFinalizeCounterRegistry.decrement(UInt(bitPattern: object))
}

private func rememberClassDefinition(
  _ definition: JavaScriptCoreClassDefinitionModel, for jsClass: JSClassRef
) {
  classDefinitionRegistry.set(UInt(bitPattern: jsClass), value: definition)
}

private func withJavaScriptCoreDynamicPropertyCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    JavaScriptCoreClassDefinitionModel,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    String
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

private func withJavaScriptCoreFunctionCallbackInput<R>(
  ctx: JSContextRef?,
  functionRef: JSObjectRef?,
  thisObjectRef: JSObjectRef?,
  _ body: (
    JavaScriptCoreClassDefinitionModel,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
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
  var functionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: functionRef, ctx: context)
  var thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObjectRef, ctx: context)
  return body(definition, context, &functionValue, &thisValue)
}

private func withJavaScriptCoreConstructorCallbackInput<R>(
  ctx: JSContextRef?,
  constructorRef: JSObjectRef?,
  _ body: (
    JavaScriptCoreClassDefinitionModel,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
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

private func withJavaScriptCoreHasInstanceCallbackInput<R>(
  ctx: JSContextRef?,
  constructorRef: JSObjectRef?,
  possibleInstanceRef: JSObjectRef?,
  _ body: (
    JavaScriptCoreClassDefinitionModel,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
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

private func withJavaScriptCoreConvertToTypeCallbackInput<R>(
  ctx: JSContextRef?,
  objectRef: JSObjectRef?,
  jsType: SwiftJavaScript.JSType,
  _ body: (
    JavaScriptCoreClassDefinitionModel,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
    SwiftJavaScript.JSType,
    inout SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> R
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

private func withJavaScriptCorePropertyNamesCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  accumulator: JSPropertyNameAccumulatorRef?,
  _ body: (
    JavaScriptCoreClassDefinitionModel,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
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

private func withJavaScriptCoreStaticValueCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> R
) -> R? {
  guard let ctx, let object,
    let definition = classDefinition(from: object),
    let propertyName = classPropertyName(propertyName)
  else {
    return nil
  }

  rememberClassObjectContext(ctx, object)
  guard
    let valueDefinition = javaScriptCoreClassDefinitionLookup().inheritedStaticValue(
      named: propertyName,
      in: definition
    )
  else {
    return nil
  }

  let context = JSInstantContext<JavaScriptCoreEngine>(ctx: ctx)
  let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: object, ctx: context)
  return body(valueDefinition, context, thisValue)
}

private func withJavaScriptCoreStaticFunctionCallbackInput<R>(
  ctx: JSContextRef?,
  function: JSObjectRef?,
  thisObject: JSObjectRef?,
  _ body: (
    SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>,
    borrowing JSInstantContext<JavaScriptCoreEngine>,
    borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>
  ) -> R
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
    let functionDefinition = javaScriptCoreClassDefinitionLookup().inheritedStaticFunction(
      named: functionName,
      in: definition
    )
  else {
    return nil
  }

  let thisValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: thisObject, ctx: context)
  return body(functionDefinition, context, thisValue)
}

func javaScriptCoreCallbackReturnValue(
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

func javaScriptCoreCallbackSucceeded(
  exceptionValue: JSValueRef?,
  exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
  guard let exceptionValue else {
    return true
  }
  exception?.pointee = exceptionValue
  return false
}

private func javaScriptCoreConstructorCallbackReturnValue(
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

private func javaScriptCoreType(from rawType: JavaScriptCore.JSType) -> SwiftJavaScript.JSType {
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

private func javaScriptCorePrivateData(fromGlobalObjectIn context: JSContextRef)
  -> UnsafeMutableRawPointer?
{
  JSObjectGetPrivate(JSContextGetGlobalObject(context))
}

private let classInitializeCallback: JSObjectInitializeCallback = { ctx, object in
  guard let ctx, let object else {
    return
  }

  rememberClassObjectContext(ctx, object)
}

private let classFinalizeCallback: JSObjectFinalizeCallback = { object in
  guard let object else {
    return
  }

  if finalizeCountAfterDecrement(object) <= 0 {
    classObjectDefinitionRegistry.remove(UInt(bitPattern: object))
    removeClassObjectContext(object)
  }
}

private func installPropertyNamesCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasPropertyEnumerator else {
    return
  }

  cls.getPropertyNames = { ctx, object, accumulator in
    let enumerated: Void? = withJavaScriptCorePropertyNamesCallbackInput(
      ctx: ctx,
      object: object,
      accumulator: accumulator
    ) { definition, context, thisValue, accumulator in
      definition.getPropertyNames?(context, &thisValue, accumulator)
    }
    guard enumerated != nil else {
      return
    }
  }
}

private func installHasPropertyCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasDynamicPropertyHas else {
    return
  }

  cls.hasProperty = { ctx, object, propertyName in
    let hasProperty = withJavaScriptCoreDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      definition.hasProperty!(context, thisValue, propertyName)
    }
    return hasProperty ?? false
  }
}

private func installDeletePropertyCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasDynamicPropertyDelete else {
    return
  }

  cls.deleteProperty = { ctx, object, propertyName, exception in
    let didDelete = withJavaScriptCoreDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      definition.deleteProperty!(context, thisValue, propertyName)
    }
    return didDelete ?? false
  }
}

private func installSetPropertyCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasDynamicPropertySetter else {
    return
  }

  cls.setProperty = { ctx, object, propertyName, value, exception in
    guard let value else {
      return false
    }
    let didSet = withJavaScriptCoreDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      let newValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: value, ctx: context)
      return javaScriptCoreCallbackSucceeded(
        exceptionValue: definition.setProperty!(
          context,
          thisValue,
          propertyName,
          newValue
        )?.takeRef(),
        exception: exception
      )
    }
    return didSet ?? false
  }
}

private func installGetPropertyCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasDynamicPropertyGetter else {
    return
  }

  cls.getProperty = { ctx, object, propertyName, exception in
    let value = withJavaScriptCoreDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      javaScriptCoreCallbackReturnValue(
        definition.getProperty!(context, thisValue, propertyName).toPrivateResult(),
        in: ctx,
        exception: exception
      )
    }
    return value ?? JSValueMakeUndefined(ctx)
  }
}

private func installCallAsFunctionCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasCallAsFunction else {
    return
  }

  cls.callAsFunction = {
    ctx, functionRef, thisObjectRef, argumentCount, arguments, exception in
    let value = withJavaScriptCoreFunctionCallbackInput(
      ctx: ctx,
      functionRef: functionRef,
      thisObjectRef: thisObjectRef
    ) { definition, context, functionValue, thisValue in
      let callbackResult: JSResult<JSValueRef> =
        withJavaScriptCoreArguments(
          arguments,
          count: Int(argumentCount)
        ) { args in
          let result =
            definition.callAsFunction?(context, &functionValue, &thisValue, args)
            ?? SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
          return JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>.value(result)
            .toPrivateResult()
        }
      return javaScriptCoreCallbackReturnValue(
        callbackResult,
        in: ctx,
        exception: exception
      )
    }
    return value ?? JSValueMakeUndefined(ctx)
  }
}

private func installHasInstanceCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasHasInstance else {
    return
  }

  cls.hasInstance = { ctx, constructorRef, possibleInstanceRef, exception in
    let hasInstance = withJavaScriptCoreHasInstanceCallbackInput(
      ctx: ctx,
      constructorRef: constructorRef,
      possibleInstanceRef: possibleInstanceRef
    ) { definition, context, constructorValue, possibleInstanceValue in
      definition.hasInstance?(context, &constructorValue, &possibleInstanceValue) ?? false
    }
    return hasInstance ?? false
  }
}

private func installCallAsConstructorCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasConstructor else {
    return
  }

  cls.callAsConstructor = {
    ctx, constructorRef, argumentCount, arguments, exception in
    let object = withJavaScriptCoreConstructorCallbackInput(
      ctx: ctx,
      constructorRef: constructorRef
    ) { definition, context, constructorValue, thisValue in
      let callbackResult: JSResult<JSValueRef> =
        withJavaScriptCoreArguments(
          arguments,
          count: Int(argumentCount)
        ) { args in
          let result =
            definition.callAsConstructor?(context, &constructorValue, &thisValue, args)
            ?? SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
          guard result.isObject(in: context) else {
            return JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>.value(
              SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
            )
            .toPrivateResult()
          }
          return JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>.value(result)
            .toPrivateResult()
        }
      return javaScriptCoreConstructorCallbackReturnValue(
        callbackResult,
        in: ctx,
        exception: exception
      )
    }
    return object ?? nil
  }
}

private func installStaticValueMembers(
  _ staticValues: [SwiftJavaScript.JSClassStaticValueDefinition],
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !staticValues.isEmpty else {
    return
  }

  backing.staticValueNames = staticValues.map { $0.name.utf8CString }
  backing.staticValues = []
  backing.staticValues.reserveCapacity(staticValues.count + 1)
  for (index, property) in staticValues.enumerated() {
    var staticValue = JavaScriptCore.JSStaticValue()
    backing.staticValueNames[index].withUnsafeBufferPointer {
      staticValue.name = $0.baseAddress
    }
    staticValue.getProperty = staticValueGetPropertyCallback
    staticValue.setProperty = staticValueSetPropertyCallback
    staticValue.attributes = property.attributes.rawValue
    backing.staticValues.append(staticValue)
  }
  backing.staticValues.append(JavaScriptCore.JSStaticValue())
  backing.staticValues.withUnsafeBufferPointer {
    cls.staticValues = $0.baseAddress
  }
}

private func installStaticFunctionMembers(
  _ staticFunctions: [SwiftJavaScript.JSClassStaticFunctionDefinition],
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !staticFunctions.isEmpty else {
    return
  }

  backing.staticFunctionNames = staticFunctions.map { $0.name.utf8CString }
  backing.staticFunctions = []
  backing.staticFunctions.reserveCapacity(staticFunctions.count + 1)
  for (index, method) in staticFunctions.enumerated() {
    var staticFunction = JavaScriptCore.JSStaticFunction()
    backing.staticFunctionNames[index].withUnsafeBufferPointer {
      staticFunction.name = $0.baseAddress
    }
    staticFunction.callAsFunction = staticFunctionCallAsFunctionCallback
    staticFunction.attributes = method.attributes.rawValue
    backing.staticFunctions.append(staticFunction)
  }
  backing.staticFunctions.append(JavaScriptCore.JSStaticFunction())
  backing.staticFunctions.withUnsafeBufferPointer {
    cls.staticFunctions = $0.baseAddress
  }
}

private func installStaticMembers(
  _ definition: SwiftJavaScript.JSClassDefinitionMetadata<JSClass>,
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installStaticValueMembers(definition.staticValues, backing: backing, into: &cls)
  installStaticFunctionMembers(definition.staticFunctions, backing: backing, into: &cls)
}

private func installLifecycleCallbacks(into cls: inout JavaScriptCore.JSClassDefinition) {
  cls.initialize = classInitializeCallback
  cls.finalize = classFinalizeCallback
}

private func installDynamicPropertyCallbacks(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installGetPropertyCallbackIfNeeded(callbacks, into: &cls)
  installSetPropertyCallbackIfNeeded(callbacks, into: &cls)
  installHasPropertyCallbackIfNeeded(callbacks, into: &cls)
  installDeletePropertyCallbackIfNeeded(callbacks, into: &cls)
  installPropertyNamesCallbackIfNeeded(callbacks, into: &cls)
}

private func installCallableCallbacks(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installCallAsFunctionCallbackIfNeeded(callbacks, into: &cls)
  installCallAsConstructorCallbackIfNeeded(callbacks, into: &cls)
  installHasInstanceCallbackIfNeeded(callbacks, into: &cls)
  installConvertToTypeCallbackIfNeeded(callbacks, into: &cls)
}

private func installClassName(
  _ className: String?,
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard let className else {
    return
  }

  backing.className = className.utf8CString
  backing.className?.withUnsafeBufferPointer {
    cls.className = $0.baseAddress
  }
}

private func installClassMetadata(
  from definition: SwiftJavaScript.JSClassDefinitionMetadata<JSClass>,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  cls.version = definition.version
  cls.attributes = definition.attributes.rawValue
  cls.parentClass = definition.parentClass?.ref
}

private func installClassCallbacks(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installLifecycleCallbacks(into: &cls)
  installDynamicPropertyCallbacks(callbacks, into: &cls)
  installCallableCallbacks(callbacks, into: &cls)
}

private func installConvertToTypeCallbackIfNeeded(
  _ callbacks: SwiftJavaScript.JSClassCallbackInstallationPlan,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard callbacks.hasConvertToType else {
    return
  }

  cls.convertToType = { ctx, objectRef, type, exception in
    let value = withJavaScriptCoreConvertToTypeCallbackInput(
      ctx: ctx,
      objectRef: objectRef,
      jsType: javaScriptCoreType(from: type)
    ) { definition, context, objectValue, jsType, exceptionValue in
      let result =
        definition.convertToType?(context, &objectValue, jsType, &exceptionValue)
        ?? SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
      let exceptionRef: JSValueRef?
      if exceptionValue.isUndefined(in: context) {
        exceptionRef = nil
      } else {
        exceptionRef = exceptionValue.takeRef()
        exceptionValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
      }
      let conversion: JSResult<JSValueRef> =
        if let exceptionRef {
          .exception(exceptionRef)
        } else {
          JSResult<SwiftJavaScript.JSValue<JavaScriptCoreEngine>>.value(result).toPrivateResult()
        }
      return javaScriptCoreCallbackReturnValue(
        conversion,
        in: ctx,
        exception: exception
      )
    }
    return value ?? JSValueMakeUndefined(ctx)
  }
}

private let staticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  let value = withJavaScriptCoreStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    javaScriptCoreCallbackReturnValue(
      valueDefinition.getProperty(context, thisValue).toPrivateResult(),
      in: ctx,
      exception: exception
    )
  }
  return value ?? JSValueMakeUndefined(ctx)
}

private let staticValueSetPropertyCallback: JSObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let value else {
    return false
  }
  let didSet = withJavaScriptCoreStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    let newValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: value, ctx: context)
    switch valueDefinition.setProperty(context, thisValue, newValue).toPrivateResult() {
    case .value:
      return true
    case .exception(let error):
      return javaScriptCoreCallbackSucceeded(
        exceptionValue: error,
        exception: exception
      )
    }
  }
  return didSet ?? false
}

private let staticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  let value = withJavaScriptCoreStaticFunctionCallbackInput(
    ctx: ctx,
    function: function,
    thisObject: thisObject
  ) { functionDefinition, context, thisValue in
    let result = withJavaScriptCoreArguments(arguments, count: Int(argumentCount)) {
      args in
      functionDefinition.callAsFunction(context, thisValue, args).toPrivateResult()
    }
    return javaScriptCoreCallbackReturnValue(
      result,
      in: ctx,
      exception: exception
    )
  }
  return value ?? JSValueMakeUndefined(ctx)
}

extension JavaScriptCoreClassDefinitionModel {

  fileprivate func manualNativeDefinition(backing: JSManualNativeClassBacking)
    -> JavaScriptCore.JSClassDefinition
  {
    var cls = JavaScriptCore.kJSClassDefinitionEmpty
    let definition = classDefinition
    let callbacks = callbackInstallationPlan

    installClassMetadata(from: definition, into: &cls)

    installClassName(definition.className, backing: backing, into: &cls)

    installStaticMembers(definition, backing: backing, into: &cls)

    installClassCallbacks(callbacks, into: &cls)

    return cls
  }
}

extension SwiftJavaScript.JSContext where E == JavaScriptCoreEngine {
  internal static func borrow(ctx: JSContextRef)
    -> SwiftJavaScript.JSContext<JavaScriptCoreEngine>
  {
    let context = Unmanaged<SwiftJavaScript.JSContext<JavaScriptCoreEngine>>.fromOpaque(
      javaScriptCorePrivateData(fromGlobalObjectIn: ctx)!
    ).takeUnretainedValue()
    return context
  }
}

extension SwiftJavaScript.JSClass where E == JavaScriptCoreEngine {
  public var ref: JSClassRef {
    classHandle().ref
  }

  public convenience init(ref: JSClassRef) {
    self.init(handleClass: JavaScriptCoreClassHandle(ref: ref))
  }

  public convenience init(
    defination: SwiftJavaScript.JSEngineClassDefinition<
      JavaScriptCoreEngine,
      JSClass,
      JSPropertyNameAccumulatorRef
    >
  ) {
    let backing = JSManualNativeClassBacking()
    var copy = defination.manualNativeDefinition(backing: backing)
    let ref = JSClassCreate(&copy)
    self.init(
      adoptingHandleClass: JavaScriptCoreClassHandle(ref: ref!),
      retainedOwner: backing
    )
    rememberClassDefinition(defination, for: self.ref)
  }

  convenience init(
    nativeDefinition: JavaScriptCore.JSClassDefinition,
    retainedBacking: AnyObject?,
    rememberedDefinition: JavaScriptCoreClassDefinitionModel? = nil
  ) {
    var copy = nativeDefinition
    let ref = JSClassCreate(&copy)
    self.init(
      adoptingHandleClass: JavaScriptCoreClassHandle(ref: ref!),
      retainedOwner: retainedBacking
    )
    if let rememberedDefinition {
      rememberClassDefinition(rememberedDefinition, for: self.ref)
    }
  }
}
