import Foundation
import JavaScriptCore

extension SwiftJavaScript.JSClassAttributes {
  public static let none = SwiftJavaScript.JSClassAttributes(
    rawValue: UInt32(kJSClassAttributeNone))
  public static let noAutomaticPrototype = SwiftJavaScript.JSClassAttributes(
    rawValue: UInt32(kJSClassAttributeNoAutomaticPrototype))
}

typealias JavaScriptCoreStaticValueModel = SwiftJavaScript.JSStaticValue<JavaScriptCoreEngine>
typealias JavaScriptCoreStaticFunctionModel = SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>
typealias JavaScriptCoreClassDefinitionModel = SwiftJavaScript.JSClassDefinition<
  JavaScriptCoreEngine,
  JSClass,
  JSPropertyNameAccumulatorRef
>
typealias JSManualNativeClassBacking = SwiftJavaScript.JSClassManualNativeClassBacking<
  JavaScriptCore.JSStaticValue,
  JavaScriptCore.JSStaticFunction
>

extension SwiftJavaScript.JSClassDefinition
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
    depth: definition.inheritanceDepth(resolvingParentDefinition: { classDefinition(for: $0.ref) })
  )
}

func rememberClassObjectFinalizeCount(
  _ object: JSObjectRef, definition: JavaScriptCoreClassDefinitionModel
) {
  classObjectFinalizeCounterRegistry.setMax(
    UInt(bitPattern: object),
    count: definition.exportedDefinitionCount(
      resolvingParentDefinition: { classDefinition(for: $0.ref) })
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
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.propertyEnumeratorBinding != nil else {
    return
  }

  cls.getPropertyNames = { ctx, object, accumulator in
    let enumerated: Void? = JavaScriptCoreEngine.withPropertyNamesCallbackInput(
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
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.dynamicPropertyHasBinding != nil else {
    return
  }

  cls.hasProperty = { ctx, object, propertyName in
    let hasProperty = JavaScriptCoreEngine.withDynamicPropertyCallbackInput(
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
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.dynamicPropertyDeleteBinding != nil else {
    return
  }

  cls.deleteProperty = { ctx, object, propertyName, exception in
    let didDelete = JavaScriptCoreEngine.withDynamicPropertyCallbackInput(
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
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.dynamicPropertySetterBinding != nil else {
    return
  }

  cls.setProperty = { ctx, object, propertyName, value, exception in
    guard let value else {
      return false
    }
    let didSet = JavaScriptCoreEngine.withDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      let newValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: value, ctx: context)
      return JavaScriptCoreEngine.callbackSucceeded(
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
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.dynamicPropertyGetterBinding != nil else {
    return
  }

  cls.getProperty = { ctx, object, propertyName, exception in
    let value = JavaScriptCoreEngine.withDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      JavaScriptCoreEngine.callbackReturnValue(
        definition.getProperty!(context, thisValue, propertyName).toPrivateResult(),
        in: ctx,
        exception: exception
      )
    }
    return value ?? JSValueMakeUndefined(ctx)
  }
}

private func installCallAsFunctionCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.callAsFunctionBinding != nil else {
    return
  }

  cls.callAsFunction = {
    ctx, functionRef, thisObjectRef, argumentCount, arguments, exception in
    let value = JavaScriptCoreEngine.withFunctionCallbackInput(
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
      return JavaScriptCoreEngine.callbackReturnValue(
        callbackResult,
        in: ctx,
        exception: exception
      )
    }
    return value ?? JSValueMakeUndefined(ctx)
  }
}

private func installHasInstanceCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.hasInstanceBinding != nil else {
    return
  }

  cls.hasInstance = { ctx, constructorRef, possibleInstanceRef, exception in
    let hasInstance = JavaScriptCoreEngine.withHasInstanceCallbackInput(
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
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.constructor?.binding != nil else {
    return
  }

  cls.callAsConstructor = {
    ctx, constructorRef, argumentCount, arguments, exception in
    let object = JavaScriptCoreEngine.withConstructorCallbackInput(
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
      return JavaScriptCoreEngine.constructorCallbackReturnValue(
        callbackResult,
        in: ctx,
        exception: exception
      )
    }
    return object ?? nil
  }
}

private func installStaticValueMembers(
  _ descriptor: JSHostTypeDescriptor,
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !descriptor.properties.isEmpty else {
    return
  }

  backing.staticValueNames = descriptor.properties.map { $0.name.utf8CString }
  backing.staticValues = []
  backing.staticValues.reserveCapacity(descriptor.properties.count + 1)
  for (index, property) in descriptor.properties.enumerated() {
    var staticValue = JavaScriptCore.JSStaticValue()
    backing.staticValueNames[index].withUnsafeBufferPointer {
      staticValue.name = $0.baseAddress
    }
    staticValue.getProperty = staticValueGetPropertyCallback
    staticValue.setProperty = staticValueSetPropertyCallback
    staticValue.attributes = javaScriptCorePropertyAttributes(from: property.attributes)
    backing.staticValues.append(staticValue)
  }
  backing.staticValues.append(JavaScriptCore.JSStaticValue())
  backing.staticValues.withUnsafeBufferPointer {
    cls.staticValues = $0.baseAddress
  }
}

private func installStaticFunctionMembers(
  _ descriptor: JSHostTypeDescriptor,
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard !descriptor.methods.isEmpty else {
    return
  }

  backing.staticFunctionNames = descriptor.methods.map { $0.name.utf8CString }
  backing.staticFunctions = []
  backing.staticFunctions.reserveCapacity(descriptor.methods.count + 1)
  for (index, method) in descriptor.methods.enumerated() {
    var staticFunction = JavaScriptCore.JSStaticFunction()
    backing.staticFunctionNames[index].withUnsafeBufferPointer {
      staticFunction.name = $0.baseAddress
    }
    staticFunction.callAsFunction = staticFunctionCallAsFunctionCallback
    staticFunction.attributes = javaScriptCorePropertyAttributes(from: method.attributes)
    backing.staticFunctions.append(staticFunction)
  }
  backing.staticFunctions.append(JavaScriptCore.JSStaticFunction())
  backing.staticFunctions.withUnsafeBufferPointer {
    cls.staticFunctions = $0.baseAddress
  }
}

private func installStaticMembers(
  _ descriptor: JSHostTypeDescriptor,
  backing: JSManualNativeClassBacking,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installStaticValueMembers(descriptor, backing: backing, into: &cls)
  installStaticFunctionMembers(descriptor, backing: backing, into: &cls)
}

private func installLifecycleCallbacks(into cls: inout JavaScriptCore.JSClassDefinition) {
  cls.initialize = classInitializeCallback
  cls.finalize = classFinalizeCallback
}

private func installDynamicPropertyCallbacks(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installGetPropertyCallbackIfNeeded(descriptor, into: &cls)
  installSetPropertyCallbackIfNeeded(descriptor, into: &cls)
  installHasPropertyCallbackIfNeeded(descriptor, into: &cls)
  installDeletePropertyCallbackIfNeeded(descriptor, into: &cls)
  installPropertyNamesCallbackIfNeeded(descriptor, into: &cls)
}

private func installCallableCallbacks(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installCallAsFunctionCallbackIfNeeded(descriptor, into: &cls)
  installCallAsConstructorCallbackIfNeeded(descriptor, into: &cls)
  installHasInstanceCallbackIfNeeded(descriptor, into: &cls)
  installConvertToTypeCallbackIfNeeded(descriptor, into: &cls)
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
  from definition: JavaScriptCoreClassDefinitionModel,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  cls.version = definition.version
  cls.attributes = definition.attributes.rawValue
  cls.parentClass = definition.parentClass?.ref
}

private func installClassCallbacks(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  installLifecycleCallbacks(into: &cls)
  installDynamicPropertyCallbacks(descriptor, into: &cls)
  installCallableCallbacks(descriptor, into: &cls)
}

private func installConvertToTypeCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard descriptor.convertToTypeBinding != nil else {
    return
  }

  cls.convertToType = { ctx, objectRef, type, exception in
    let value = JavaScriptCoreEngine.withConvertToTypeCallbackInput(
      ctx: ctx,
      objectRef: objectRef,
      jsType: JavaScriptCoreEngine.jsType(from: type)
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
      return JavaScriptCoreEngine.callbackReturnValue(
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
  let value = JavaScriptCoreEngine.withStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    JavaScriptCoreEngine.callbackReturnValue(
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
  let didSet = JavaScriptCoreEngine.withStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    let newValue = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(ref: value, ctx: context)
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
  return didSet ?? false
}

private let staticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  let value = JavaScriptCoreEngine.withStaticFunctionCallbackInput(
    ctx: ctx,
    function: function,
    thisObject: thisObject
  ) { functionDefinition, context, thisValue in
    let result = withJavaScriptCoreArguments(arguments, count: Int(argumentCount)) {
      args in
      functionDefinition.callAsFunction(context, thisValue, args).toPrivateResult()
    }
    return JavaScriptCoreEngine.callbackReturnValue(
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
    let descriptor = hostTypeDescriptor()

    installClassMetadata(from: self, into: &cls)

    installClassName(className, backing: backing, into: &cls)

    installStaticMembers(descriptor, backing: backing, into: &cls)

    installClassCallbacks(descriptor, into: &cls)

    return cls
  }
}

extension SwiftJavaScript.JSContext where E == JavaScriptCoreEngine {
  internal static func borrow(ctx: JSContextRef)
    -> SwiftJavaScript.JSContext<JavaScriptCoreEngine>
  {
    let context = Unmanaged<SwiftJavaScript.JSContext<JavaScriptCoreEngine>>.fromOpaque(
      JavaScriptCoreEngine.privateData(fromGlobalObjectIn: ctx)!
    ).takeUnretainedValue()
    return context
  }
}

public class JSClass: @unchecked Sendable {
  public let ref: JSClassRef
  private let nativeBacking: AnyObject?

  public init(ref: JSClassRef) {
    self.ref = JSClassRetain(ref)
    self.nativeBacking = nil
  }

  public init(
    defination: SwiftJavaScript.JSClassDefinition<
      JavaScriptCoreEngine,
      JSClass,
      JSPropertyNameAccumulatorRef
    >
  ) {
    let backing = JSManualNativeClassBacking()
    var copy = defination.manualNativeDefinition(backing: backing)
    self.ref = JSClassCreate(&copy)
    self.nativeBacking = backing
    rememberClassDefinition(defination, for: ref)
  }

  init(
    nativeDefinition: JavaScriptCore.JSClassDefinition,
    retainedBacking: AnyObject?,
    rememberedDefinition: JavaScriptCoreClassDefinitionModel? = nil
  ) {
    var copy = nativeDefinition
    self.ref = JSClassCreate(&copy)
    self.nativeBacking = retainedBacking
    if let rememberedDefinition {
      rememberClassDefinition(rememberedDefinition, for: ref)
    }
  }

  deinit {
    JSClassRelease(ref)
  }
}
