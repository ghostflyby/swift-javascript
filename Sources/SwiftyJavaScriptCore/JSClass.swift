import Foundation
import JavaScriptCore

/// The JavaScriptCore class wrapper (S11).
///
/// A concrete `final class` over one retained `JSCClassRef`: creating a wrapper
/// retains the class once, and dropping it releases that reference once. The
/// wrapper keeps the Swift side alive (`retainedOwner`): the manual class
/// backing (names/static tables) and the auto class backing both outlive the
/// raw `JSClassRef` only through this owner.
public final class JSCClass: SwiftJavaScript.JSClass, @unchecked Sendable {
  public typealias Context = JSCContext

  package let handle: JSCClassHandle
  package let retainedOwner: AnyObject?

  package init(handleClass: JSCClassHandle, retainedOwner: AnyObject? = nil) {
    self.handle = handleClass
    self.retainedOwner = retainedOwner
    _ = handleClass.retainReference()
  }

  package init(adoptingHandleClass: JSCClassHandle, retainedOwner: AnyObject? = nil) {
    self.handle = adoptingHandleClass
    self.retainedOwner = retainedOwner
  }

  deinit {
    _ = handle.releaseReference()
  }
}

extension JSCClass: Equatable {
  public static func == (lhs: JSCClass, rhs: JSCClass) -> Bool {
    lhs.handle == rhs.handle
  }
}

extension JSCClass: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(handle)
  }
}

package struct JSCClassHandle: SwiftJavaScript.JSClassManualReferenceCountedHandle,
  @unchecked Sendable
{
  package let ref: JSClassRef

  package init(ref: JSClassRef) {
    self.ref = ref
  }

  @discardableResult
  package func retainReference() -> Bool {
    JSClassRetain(ref)
    return true
  }

  @discardableResult
  package func releaseReference() -> Bool {
    JSClassRelease(ref)
    return true
  }
}

extension JSCClassHandle: Hashable {
  package static func == (lhs: JSCClassHandle, rhs: JSCClassHandle)
    -> Bool
  {
    lhs.ref == rhs.ref
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(UInt(bitPattern: ref))
  }
}

typealias JSCClassDefinitionModel = SwiftJavaScript.JSEngineClassDefinition<
  JSCEngine,
  JSCClass,
  JSPropertyNameAccumulatorRef
>
typealias JSCManualNativeClassBacking = SwiftJavaScript.JSClassManualNativeClassBacking<
  JavaScriptCore.JSStaticValue,
  JavaScriptCore.JSStaticFunction
>

extension SwiftJavaScript.JSEngineClassDefinition
where
  E == JSCEngine,
  ParentClass == JSCClass,
  PropertyNameAccumulator == JSPropertyNameAccumulatorRef
{
  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer
  ) -> JSHostTypeDescriptor {
    hostTypeDescriptor(
      storagePolicy: storagePolicy,
      parentName: parentClass.flatMap {
        classDefinitionRegistry[UInt(bitPattern: $0.ref)]?.className
      }
    )
  }
}

private typealias JSClassObjectContextRegistry = SwiftJavaScript.JSClassMapRegistry<
  UInt, UInt
>
private typealias JSCClassDefinitionModelRegistry = SwiftJavaScript.JSClassMapRegistry<
  UInt,
  JSCClassDefinitionModel
>

private let classObjectContextRegistry = JSClassObjectContextRegistry()

private typealias JSClassObjectDefinitionRegistry = SwiftJavaScript.JSClassDefinitionDepthRegistry<
  UInt,
  JSCClassDefinitionModel
>
private typealias JSClassObjectFinalizeCounterRegistry =
  SwiftJavaScript.JSClassFinalizeCounterRegistry<UInt>

private let classDefinitionRegistry = JSCClassDefinitionModelRegistry()
private let classObjectDefinitionRegistry = JSClassObjectDefinitionRegistry()
private let classObjectFinalizeCounterRegistry = JSClassObjectFinalizeCounterRegistry()

func resolveJavaScriptCoreParentClassDefinition(_ parentClass: JSCClass)
  -> JSCClassDefinitionModel?
{
  classDefinition(for: parentClass.ref)
}

func javaScriptCoreClassDefinitionLookup()
  -> SwiftJavaScript.JSEngineClassDefinitionLookup<
    JSCEngine,
    JSCClass,
    JSPropertyNameAccumulatorRef
  >
{
  SwiftJavaScript.JSEngineClassDefinitionLookup {
    resolveJavaScriptCoreParentClassDefinition($0)
  }
}

func makeRememberedClassCallbackContext(
  _ ctx: JSContextRef, _ object: JSObjectRef
) -> JSCInstantContext {
  rememberClassObjectContext(ctx, object)
  return JSCInstantContext(handle: JSCContextHandle(borrowing: ctx))
}

func withRememberedClassObjectValue<R>(
  _ ctx: JSContextRef,
  object: JSObjectRef,
  _ body: (
    borrowing JSCInstantContext,
    borrowing JSCValue
  ) -> R
) -> R {
  let context = makeRememberedClassCallbackContext(ctx, object)
  let thisValue = JSCValue(ref: object, in: context)
  return body(context, thisValue)
}

func withStoredClassObjectValue<R>(
  _ object: JSObjectRef,
  _ body: (
    borrowing JSCInstantContext,
    borrowing JSCValue
  ) -> R
) -> R? {
  guard let objectContext = classObjectContext(object) else {
    return nil
  }
  let context = JSCInstantContext(handle: JSCContextHandle(borrowing: objectContext))
  let thisValue = JSCValue(ref: object, in: context)
  return body(context, thisValue)
}

func classPropertyName(_ propertyName: JSStringRef?) -> String? {
  guard let propertyName else {
    return nil
  }
  return javaScriptCoreString(propertyName)
}

func rememberClassObjectContext(_ ctx: JSContextRef, _ object: JSObjectRef) {
  classObjectContextRegistry[UInt(bitPattern: object)] = UInt(bitPattern: ctx)
}

func classObjectContext(_ object: JSObjectRef) -> JSContextRef? {
  guard let contextAddress = classObjectContextRegistry[UInt(bitPattern: object)] else {
    return nil
  }
  return JSContextRef(bitPattern: contextAddress)
}

func removeClassObjectContext(_ object: JSObjectRef) {
  classObjectContextRegistry.removeValue(forKey: UInt(bitPattern: object))
}

func classDefinition(from object: JSObjectRef) -> JSCClassDefinitionModel? {
  classObjectDefinitionRegistry.get(UInt(bitPattern: object))
}

func classDefinition(for jsClass: JSClassRef) -> JSCClassDefinitionModel? {
  classDefinitionRegistry[UInt(bitPattern: jsClass)]
}

func rememberClassObjectDefinition(
  _ object: JSObjectRef, definition: JSCClassDefinitionModel
) {
  classObjectDefinitionRegistry.set(
    UInt(bitPattern: object),
    definition: definition,
    depth: javaScriptCoreClassDefinitionLookup().inheritanceDepth(of: definition)
  )
}

func rememberClassObjectFinalizeCount(
  _ object: JSObjectRef, definition: JSCClassDefinitionModel
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
  _ definition: JSCClassDefinitionModel, for jsClass: JSClassRef
) {
  classDefinitionRegistry[UInt(bitPattern: jsClass)] = definition
}

private func withJavaScriptCoreDynamicPropertyCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    JSCClassDefinitionModel,
    borrowing JSCInstantContext,
    borrowing JSCValue,
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
  let thisValue = JSCValue(ref: object, in: context)
  return body(definition, context, thisValue, propertyName)
}

private func withJavaScriptCoreFunctionCallbackInput<R>(
  ctx: JSContextRef?,
  functionRef: JSObjectRef?,
  thisObjectRef: JSObjectRef?,
  _ body: (
    JSCClassDefinitionModel,
    borrowing JSCInstantContext,
    inout JSCValue,
    inout JSCValue
  ) -> R
) -> R? {
  guard let ctx, let functionRef, let thisObjectRef,
    let definition = classDefinition(from: thisObjectRef)
  else {
    return nil
  }

  let context = makeRememberedClassCallbackContext(ctx, thisObjectRef)
  var functionValue = JSCValue(ref: functionRef, in: context)
  var thisValue = JSCValue(ref: thisObjectRef, in: context)
  return body(definition, context, &functionValue, &thisValue)
}

private func withJavaScriptCoreConstructorCallbackInput<R>(
  ctx: JSContextRef?,
  constructorRef: JSObjectRef?,
  _ body: (
    JSCClassDefinitionModel,
    borrowing JSCInstantContext,
    inout JSCValue,
    inout JSCValue
  ) -> R
) -> R? {
  guard let ctx, let constructorRef,
    let definition = classDefinition(from: constructorRef)
  else {
    return nil
  }

  let context = makeRememberedClassCallbackContext(ctx, constructorRef)
  var constructorValue = JSCValue(ref: constructorRef, in: context)
  var thisValue = JSCValue(undefinedIn: context)
  return body(definition, context, &constructorValue, &thisValue)
}

private func withJavaScriptCoreHasInstanceCallbackInput<R>(
  ctx: JSContextRef?,
  constructorRef: JSObjectRef?,
  possibleInstanceRef: JSObjectRef?,
  _ body: (
    JSCClassDefinitionModel,
    borrowing JSCInstantContext,
    inout JSCValue,
    inout JSCValue
  ) -> R
) -> R? {
  guard let ctx, let constructorRef, let possibleInstanceRef,
    let definition = classDefinition(from: constructorRef)
  else {
    return nil
  }

  let context = makeRememberedClassCallbackContext(ctx, constructorRef)
  var constructorValue = JSCValue(ref: constructorRef, in: context)
  var possibleInstanceValue = JSCValue(ref: possibleInstanceRef, in: context)
  return body(definition, context, &constructorValue, &possibleInstanceValue)
}

private func withJavaScriptCoreConvertToTypeCallbackInput<R>(
  ctx: JSContextRef?,
  objectRef: JSObjectRef?,
  jsType: SwiftJavaScript.JSType,
  _ body: (
    JSCClassDefinitionModel,
    borrowing JSCInstantContext,
    inout JSCValue,
    SwiftJavaScript.JSType,
    inout JSCValue
  ) -> R
) -> R? {
  guard let ctx, let objectRef,
    let definition = classDefinition(from: objectRef)
  else {
    return nil
  }

  let context = makeRememberedClassCallbackContext(ctx, objectRef)
  var objectValue = JSCValue(ref: objectRef, in: context)
  var exceptionValue = JSCValue(undefinedIn: context)
  return body(definition, context, &objectValue, jsType, &exceptionValue)
}

private func withJavaScriptCorePropertyNamesCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  accumulator: JSPropertyNameAccumulatorRef?,
  _ body: (
    JSCClassDefinitionModel,
    borrowing JSCInstantContext,
    inout JSCValue,
    JSPropertyNameAccumulatorRef
  ) -> R
) -> R? {
  guard let ctx, let object, let accumulator,
    let definition = classDefinition(from: object)
  else {
    return nil
  }

  let context = makeRememberedClassCallbackContext(ctx, object)
  var thisValue = JSCValue(ref: object, in: context)
  return body(definition, context, &thisValue, accumulator)
}

private func withJavaScriptCoreStaticValueCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (
    SwiftJavaScript.JSStaticValue<JSCEngine>,
    borrowing JSCInstantContext,
    borrowing JSCValue
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
    let valueDefinition = definition.inheritedStaticValue(
      named: propertyName,
      resolvingParentDefinition: resolveJavaScriptCoreParentClassDefinition
    )
  else {
    return nil
  }

  let context = JSCInstantContext(handle: JSCContextHandle(borrowing: ctx))
  let thisValue = JSCValue(ref: object, in: context)
  return body(valueDefinition, context, thisValue)
}

private func withJavaScriptCoreStaticFunctionCallbackInput<R>(
  ctx: JSContextRef?,
  function: JSObjectRef?,
  thisObject: JSObjectRef?,
  _ body: (
    SwiftJavaScript.JSStaticFunction<JSCEngine>,
    borrowing JSCInstantContext,
    borrowing JSCValue
  ) -> R
) -> R? {
  guard let ctx, let function, let thisObject,
    let definition = classDefinition(from: thisObject)
  else {
    return nil
  }

  rememberClassObjectContext(ctx, thisObject)
  let context = makeRememberedClassCallbackContext(ctx, thisObject)
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
      resolvingParentDefinition: resolveJavaScriptCoreParentClassDefinition
    )
  else {
    return nil
  }

  let thisValue = JSCValue(ref: thisObject, in: context)
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

func javaScriptCoreContextDataStorageBox(from context: JSContextRef)
  -> SwiftJavaScript.JSContextDataStorageBox?
{
  guard let privateData = javaScriptCorePrivateData(fromGlobalObjectIn: context) else {
    return nil
  }
  return Unmanaged<SwiftJavaScript.JSContextDataStorageBox>
    .fromOpaque(privateData)
    .takeUnretainedValue()
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
      definition.hasDynamicProperty(in: context, on: thisValue, forKey: propertyName)
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
      definition.deleteDynamicProperty(in: context, on: thisValue, forKey: propertyName)
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
      let newValue = JSCValue(ref: value, in: context)
      return javaScriptCoreCallbackSucceeded(
        exceptionValue: definition.setDynamicPropertyException(
          in: context,
          on: thisValue,
          forKey: propertyName,
          to: newValue
        )?.ref,
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
        definition.dynamicPropertyValue(
          in: context,
          on: thisValue,
          forKey: propertyName
        ).toPrivateResult(),
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
            ?? JSCValue(undefinedIn: context)
          return JSResult<JSCValue>.value(result)
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
            ?? JSCValue(undefinedIn: context)
          guard result.isObject() else {
            return JSResult<JSCValue>.value(
              JSCValue(undefinedIn: context)
            )
            .toPrivateResult()
          }
          return JSResult<JSCValue>.value(result)
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
  backing: JSCManualNativeClassBacking,
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
  backing: JSCManualNativeClassBacking,
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
  _ definition: SwiftJavaScript.JSClassDefinitionMetadata<JSCClass>,
  backing: JSCManualNativeClassBacking,
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
  backing: JSCManualNativeClassBacking,
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
  from definition: SwiftJavaScript.JSClassDefinitionMetadata<JSCClass>,
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
        ?? JSCValue(undefinedIn: context)
      let exceptionRef: JSValueRef?
      if exceptionValue.isUndefined() {
        exceptionRef = nil
      } else {
        exceptionRef = exceptionValue.ref
        exceptionValue = JSCValue(undefinedIn: context)
      }
      let conversion: JSResult<JSValueRef> =
        if let exceptionRef {
          .exception(exceptionRef)
        } else {
          JSResult<JSCValue>.value(result).toPrivateResult()
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
      valueDefinition.propertyValue(in: context, on: thisValue).toPrivateResult(),
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
    let newValue = JSCValue(ref: value, in: context)
    return javaScriptCoreCallbackSucceeded(
      exceptionValue: valueDefinition.setPropertyException(
        in: context,
        on: thisValue,
        to: newValue
      )?.ref,
      exception: exception
    )
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

extension JSCClassDefinitionModel {

  fileprivate func manualNativeDefinition(backing: JSCManualNativeClassBacking)
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

/// The context that installed the data box behind a raw callback context.
///
/// A raw `JSContextRef` inside a class callback has no Swift owner, so the box
/// is the only route back to it. Every failure is a `nil`, never a force
/// unwrap: a bare engine context may have no box or no bound owner at all.
extension JSCContext {
  internal static func borrow(ctx: JSContextRef) -> JSCContext? {
    guard
      let box = javaScriptCoreContextDataStorageBox(from: ctx),
      let owner = box.borrowContextOwner()
    else {
      return nil
    }
    return owner as? JSCContext
  }
}

extension JSCClass {
  package var ref: JSClassRef {
    handle.ref
  }

  package convenience init(ref: JSClassRef) {
    self.init(handleClass: JSCClassHandle(ref: ref))
  }

  public convenience init(
    defination: SwiftJavaScript.JSEngineClassDefinition<
      JSCEngine,
      JSCClass,
      JSPropertyNameAccumulatorRef
    >
  ) {
    let backing = JSCManualNativeClassBacking()
    var copy = defination.manualNativeDefinition(backing: backing)
    let ref = JSClassCreate(&copy)
    self.init(
      adoptingHandleClass: JSCClassHandle(ref: ref!),
      retainedOwner: backing
    )
    rememberClassDefinition(defination, for: self.ref)
  }

  convenience init(
    nativeDefinition: JavaScriptCore.JSClassDefinition,
    retainedBacking: AnyObject?,
    rememberedDefinition: JSCClassDefinitionModel? = nil
  ) {
    var copy = nativeDefinition
    let ref = JSClassCreate(&copy)
    self.init(
      adoptingHandleClass: JSCClassHandle(ref: ref!),
      retainedOwner: retainedBacking
    )
    if let rememberedDefinition {
      rememberClassDefinition(rememberedDefinition, for: self.ref)
    }
  }
}
