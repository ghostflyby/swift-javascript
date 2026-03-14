import Foundation
import JavaScriptCore

public struct JSClassAttributes: OptionSet, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let none = JSClassAttributes(rawValue: UInt32(kJSClassAttributeNone))
  public static let noAutomaticPrototype = JSClassAttributes(
    rawValue: UInt32(kJSClassAttributeNoAutomaticPrototype))
}

public struct JSStaticValue: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let getProperty: @Sendable (borrowing JSInstantContext, borrowing JSValue) -> JSResult
  public let setProperty:
    @Sendable (borrowing JSInstantContext, borrowing JSValue, borrowing JSValue) -> JSResult
}

public struct JSStaticFunction: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let callAsFunction:
    @Sendable (borrowing JSInstantContext, borrowing JSValue, borrowing JSArguments) -> JSResult
}

extension JSStaticValue {
  public func hostPropertyDescriptor(
    getterBinding: String? = nil,
    setterBinding: String? = nil
  ) -> JSHostPropertyDescriptor {
    JSHostPropertyDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      getterBinding: getterBinding,
      setterBinding: setterBinding
    )
  }
}

extension JSStaticFunction {
  public func hostFunctionDescriptor(binding: String? = nil) -> JSHostFunctionDescriptor {
    JSHostFunctionDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      binding: binding
    )
  }
}

public struct JSClassDefinition: Sendable {

  public var version: Int32 = 0

  public var attributes: JSClassAttributes = .none

  public var className: String? {
    didSet {
      if let className {
        _className = className.utf8CString
      } else {
        _className = nil
      }
    }
  }

  private var _className: ContiguousArray<CChar>? = nil

  public var parentClass: JSClass? = nil

  public var staticValues: [JSStaticValue] = []

  public var staticFunctions: [JSStaticFunction] = []

  public var initialize: (@Sendable (borrowing JSValue, borrowing JSInstantContext) -> Void)? = nil

  public var finalize: (@Sendable (borrowing JSValue) -> Void)? = nil

  public var hasProperty:
    (@Sendable (borrowing JSInstantContext, borrowing JSValue, String) -> Bool)? = nil

  public var getProperty:
    (@Sendable (borrowing JSInstantContext, borrowing JSValue, String) -> JSResult)? =
      nil

  public var setProperty:
    (
      @Sendable (borrowing JSInstantContext, borrowing JSValue, String, borrowing JSValue) ->
        JSValue?
    )? =
      nil

  public var deleteProperty:
    (@Sendable (borrowing JSInstantContext, borrowing JSValue, String) -> Bool)? =
      nil

  public var getPropertyNames:
    (@Sendable (borrowing JSInstantContext, inout JSValue, JSPropertyNameAccumulatorRef) -> Void)? =
      nil

  public var callAsFunction:
    (
      @Sendable (borrowing JSInstantContext, inout JSValue, inout JSValue, borrowing JSArguments)
        ->
        JSValue
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (borrowing JSInstantContext, inout JSValue, inout JSValue, borrowing JSArguments)
        ->
        JSValue
    )? = nil

  public var hasInstance:
    (@Sendable (borrowing JSInstantContext, inout JSValue, inout JSValue) -> Bool)? =
      nil

  public var convertToType:
    (@Sendable (borrowing JSInstantContext, inout JSValue, JSType, inout JSValue) -> JSValue)? =
      nil

  public func hostTypeDescriptor(
    storagePolicy: JSHostObjectStoragePolicy = .unmanagedOpaquePointer
  ) -> JSHostTypeDescriptor {
    let typeName = className ?? "AnonymousHostType"

    return JSHostTypeDescriptor(
      name: typeName,
      constructor: callAsConstructor == nil
        ? nil
        : JSHostConstructorDescriptor(binding: hostBindingName(suffix: "constructor")),
      methods: staticFunctions.map {
        $0.hostFunctionDescriptor(binding: hostBindingName(suffix: "method.\($0.name)"))
      },
      staticMethods: [],
      properties: staticValues.map {
        $0.hostPropertyDescriptor(
          getterBinding: hostBindingName(suffix: "property.get.\($0.name)"),
          setterBinding: hostBindingName(suffix: "property.set.\($0.name)")
        )
      },
      parent: parentClass.flatMap { classDefinitionRegistry.get($0.ref)?.className },
      storagePolicy: storagePolicy,
      initializerBinding: initialize == nil ? nil : hostBindingName(suffix: "initialize"),
      finalizerBinding: finalize == nil ? nil : hostBindingName(suffix: "finalize"),
      dynamicPropertyGetterBinding: getProperty == nil
        ? nil
        : hostBindingName(suffix: "dynamicProperty.get"),
      dynamicPropertySetterBinding: setProperty == nil
        ? nil
        : hostBindingName(suffix: "dynamicProperty.set"),
      dynamicPropertyHasBinding: hasProperty == nil
        ? nil
        : hostBindingName(suffix: "dynamicProperty.has"),
      dynamicPropertyDeleteBinding: deleteProperty == nil
        ? nil
        : hostBindingName(suffix: "dynamicProperty.delete"),
      propertyEnumeratorBinding: getPropertyNames == nil
        ? nil
        : hostBindingName(suffix: "dynamicProperty.enumerate"),
      callAsFunctionBinding: callAsFunction == nil ? nil : hostBindingName(suffix: "call"),
      hasInstanceBinding: hasInstance == nil ? nil : hostBindingName(suffix: "hasInstance"),
      convertToTypeBinding: convertToType == nil
        ? nil
        : hostBindingName(suffix: "convertToType")
    )
  }

  private func hostBindingName(suffix: String) -> String {
    guard let className, !className.isEmpty else {
      return suffix
    }
    return "\(className).\(suffix)"
  }
}

final class JSManualNativeClassBacking {
  var className: ContiguousArray<CChar>? = nil
  var staticValueNames: [ContiguousArray<CChar>] = []
  var staticValues: [JavaScriptCore.JSStaticValue] = []
  var staticFunctionNames: [ContiguousArray<CChar>] = []
  var staticFunctions: [JavaScriptCore.JSStaticFunction] = []
}

private final class JSClassObjectContextRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [UInt: JSContextRef] = [:]

  func set(_ object: JSObjectRef, context: JSContextRef) {
    lock.lock()
    map[classObjectKey(object)] = context
    lock.unlock()
  }

  func get(_ object: JSObjectRef) -> JSContextRef? {
    lock.lock()
    let value = map[classObjectKey(object)]
    lock.unlock()
    return value
  }

  func remove(_ object: JSObjectRef) {
    lock.lock()
    map.removeValue(forKey: classObjectKey(object))
    lock.unlock()
  }
}

private let classObjectContextRegistry = JSClassObjectContextRegistry()

private final class JSClassDefinitionRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [UInt: JSClassDefinition] = [:]

  func set(_ jsClass: JSClassRef, definition: JSClassDefinition) {
    lock.lock()
    map[classKey(jsClass)] = definition
    lock.unlock()
  }

  func get(_ jsClass: JSClassRef) -> JSClassDefinition? {
    lock.lock()
    let value = map[classKey(jsClass)]
    lock.unlock()
    return value
  }
}

private final class JSClassObjectDefinitionRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [UInt: (definition: JSClassDefinition, depth: Int)] = [:]

  func set(_ object: JSObjectRef, definition: JSClassDefinition, depth: Int) {
    lock.lock()
    let key = classObjectKey(object)
    if let current = map[key], current.depth > depth {
      lock.unlock()
      return
    }
    map[key] = (definition, depth)
    lock.unlock()
  }

  func get(_ object: JSObjectRef) -> JSClassDefinition? {
    lock.lock()
    let value = map[classObjectKey(object)]?.definition
    lock.unlock()
    return value
  }

  func remove(_ object: JSObjectRef) {
    lock.lock()
    map.removeValue(forKey: classObjectKey(object))
    lock.unlock()
  }
}

private final class JSClassObjectFinalizeCounterRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var map: [UInt: Int] = [:]

  func setMax(_ object: JSObjectRef, count: Int) {
    lock.lock()
    let key = classObjectKey(object)
    map[key] = max(count, map[key] ?? 0)
    lock.unlock()
  }

  func decrement(_ object: JSObjectRef) -> Int {
    lock.lock()
    let key = classObjectKey(object)
    let current = map[key] ?? 1
    let next = current - 1
    if next <= 0 {
      map.removeValue(forKey: key)
    } else {
      map[key] = next
    }
    lock.unlock()
    return next
  }
}

private let classDefinitionRegistry = JSClassDefinitionRegistry()
private let classObjectDefinitionRegistry = JSClassObjectDefinitionRegistry()
private let classObjectFinalizeCounterRegistry = JSClassObjectFinalizeCounterRegistry()

func makeRememberedClassCallbackContext(_ ctx: JSContextRef, _ object: JSObjectRef)
  -> JSInstantContext
{
  rememberClassObjectContext(ctx, object)
  return JSInstantContext(ctx: ctx)
}

func classPropertyName(_ propertyName: JSStringRef?) -> String? {
  guard let propertyName else {
    return nil
  }
  return String(jsStringRef: propertyName)
}

private func classObjectKey(_ object: JSObjectRef) -> UInt {
  UInt(bitPattern: object)
}

private func classKey(_ jsClass: JSClassRef) -> UInt {
  UInt(bitPattern: jsClass)
}

func rememberClassObjectContext(_ ctx: JSContextRef, _ object: JSObjectRef) {
  classObjectContextRegistry.set(object, context: ctx)
}

func classObjectContext(_ object: JSObjectRef) -> JSContextRef? {
  classObjectContextRegistry.get(object)
}

func removeClassObjectContext(_ object: JSObjectRef) {
  classObjectContextRegistry.remove(object)
}

func classDefinition(from object: JSObjectRef) -> JSClassDefinition? {
  classObjectDefinitionRegistry.get(object)
}

func classDefinition(for jsClass: JSClassRef) -> JSClassDefinition? {
  classDefinitionRegistry.get(jsClass)
}

private func definitionDepth(_ definition: JSClassDefinition) -> Int {
  guard let parentClass = definition.parentClass,
    let parentDefinition = classDefinition(for: parentClass.ref)
  else {
    return 1
  }
  return 1 + definitionDepth(parentDefinition)
}

func rememberClassObjectDefinition(_ object: JSObjectRef, definition: JSClassDefinition) {
  classObjectDefinitionRegistry.set(
    object, definition: definition, depth: definitionDepth(definition))
}

func exportedDefinitionCount(_ definition: JSClassDefinition) -> Int {
  guard let parentClass = definition.parentClass,
    let parentDefinition = classDefinition(for: parentClass.ref)
  else {
    return 1
  }
  return 1 + exportedDefinitionCount(parentDefinition)
}

func rememberClassObjectFinalizeCount(_ object: JSObjectRef, definition: JSClassDefinition) {
  classObjectFinalizeCounterRegistry.setMax(object, count: exportedDefinitionCount(definition))
}

private func finalizeCountAfterDecrement(_ object: JSObjectRef) -> Int {
  classObjectFinalizeCounterRegistry.decrement(object)
}

private func rememberClassDefinition(_ definition: JSClassDefinition, for jsClass: JSClassRef) {
  classDefinitionRegistry.set(jsClass, definition: definition)
}

func inheritedStaticValue(named name: String, from definition: JSClassDefinition)
  -> JSStaticValue?
{
  if let value = definition.staticValues.first(where: { $0.name == name }) {
    return value
  }
  guard let parentClass = definition.parentClass,
    let parentDefinition = classDefinition(for: parentClass.ref)
  else {
    return nil
  }
  return inheritedStaticValue(named: name, from: parentDefinition)
}

func inheritedStaticFunction(named name: String, from definition: JSClassDefinition)
  -> JSStaticFunction?
{
  if let function = definition.staticFunctions.first(where: { $0.name == name }) {
    return function
  }
  guard let parentClass = definition.parentClass,
    let parentDefinition = classDefinition(for: parentClass.ref)
  else {
    return nil
  }
  return inheritedStaticFunction(named: name, from: parentDefinition)
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
    classObjectDefinitionRegistry.remove(object)
    removeClassObjectContext(object)
  }
}

private func callbackValueOrUndefined(_ value: JSValueRef?, in ctx: JSContextRef?) -> JSValueRef? {
  value ?? JSValueMakeUndefined(ctx)
}

private func callbackValueOrUndefined(_ value: JSValueRef??, in ctx: JSContextRef?) -> JSValueRef? {
  value ?? JSValueMakeUndefined(ctx)
}

private func callbackBoolOrFalse(_ value: Bool?) -> Bool {
  value ?? false
}

private func callbackObjectOrNil(_ value: JSObjectRef?) -> JSObjectRef? {
  value
}

private func callbackObjectOrNil(_ value: JSObjectRef??) -> JSObjectRef? {
  value ?? nil
}

private func callbackDidRun(_ value: Void?) -> Bool {
  value != nil
}

private func installPropertyNamesCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasPropertyEnumerator(for: descriptor) else {
    return
  }

  cls.getPropertyNames = { ctx, object, accumulator in
    let enumerated: Void? = JavaScriptCoreBackendDriver.withPropertyNamesCallbackInput(
      ctx: ctx,
      object: object,
      accumulator: accumulator
    ) { definition, context, thisValue, accumulator in
      definition.getPropertyNames?(context, &thisValue, accumulator)
    }
    guard callbackDidRun(enumerated) else {
      return
    }
  }
}

private func installHasPropertyCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasDynamicPropertyHas(for: descriptor) else {
    return
  }

  cls.hasProperty = { ctx, object, propertyName in
    let hasProperty = JavaScriptCoreBackendDriver.withDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      definition.hasProperty!(context, thisValue, propertyName)
    }
    return callbackBoolOrFalse(hasProperty)
  }
}

private func installDeletePropertyCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasDynamicPropertyDelete(for: descriptor) else {
    return
  }

  cls.deleteProperty = { ctx, object, propertyName, exception in
    let didDelete = JavaScriptCoreBackendDriver.withDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      definition.deleteProperty!(context, thisValue, propertyName)
    }
    return callbackBoolOrFalse(didDelete)
  }
}

private func installSetPropertyCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasDynamicPropertySetter(for: descriptor) else {
    return
  }

  cls.setProperty = { ctx, object, propertyName, value, exception in
    guard let value else {
      return false
    }
    let didSet = JavaScriptCoreBackendDriver.withDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      let newValue = JSValue(ref: value, ctx: context)
      return JavaScriptCoreBackendDriver.callbackSucceeded(
        exceptionValue: definition.setProperty!(
          context,
          thisValue,
          propertyName,
          newValue
        )?.retainedRef(),
        exception: exception
      )
    }
    return callbackBoolOrFalse(didSet)
  }
}

private func installGetPropertyCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasDynamicPropertyGetter(for: descriptor) else {
    return
  }

  cls.getProperty = { ctx, object, propertyName, exception in
    let value = JavaScriptCoreBackendDriver.withDynamicPropertyCallbackInput(
      ctx: ctx,
      object: object,
      propertyName: propertyName
    ) { definition, context, thisValue, propertyName in
      JavaScriptCoreBackendDriver.callbackReturnValue(
        definition.getProperty!(context, thisValue, propertyName).toPrivateResult(),
        in: ctx,
        exception: exception
      )
    }
    return callbackValueOrUndefined(value, in: ctx)
  }
}

private func installCallAsFunctionCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasCallAsFunction(for: descriptor) else {
    return
  }

  cls.callAsFunction = {
    ctx, functionRef, thisObjectRef, argumentCount, arguments, exception in
    let value = JavaScriptCoreBackendDriver.withFunctionCallbackInput(
      ctx: ctx,
      functionRef: functionRef,
      thisObjectRef: thisObjectRef
    ) { definition, context, functionValue, thisValue in
      let callbackResult: JSPrivateResult = JavaScriptCoreBackendDriver.withArguments(
        arguments,
        count: Int(argumentCount)
      ) { args in
        let result =
          definition.callAsFunction?(context, &functionValue, &thisValue, args)
          ?? JSValue(undefinedIn: context)
        return .value(result.retainedRef())
      }
      return JavaScriptCoreBackendDriver.callbackReturnValue(
        callbackResult,
        in: ctx,
        exception: exception
      )
    }
    return callbackValueOrUndefined(value, in: ctx)
  }
}

private func installHasInstanceCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasHasInstance(for: descriptor) else {
    return
  }

  cls.hasInstance = { ctx, constructorRef, possibleInstanceRef, exception in
    let hasInstance = JavaScriptCoreBackendDriver.withHasInstanceCallbackInput(
      ctx: ctx,
      constructorRef: constructorRef,
      possibleInstanceRef: possibleInstanceRef
    ) { definition, context, constructorValue, possibleInstanceValue in
      definition.hasInstance?(context, &constructorValue, &possibleInstanceValue) ?? false
    }
    return callbackBoolOrFalse(hasInstance)
  }
}

private func installCallAsConstructorCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasConstructor(for: descriptor) else {
    return
  }

  cls.callAsConstructor = {
    ctx, constructorRef, argumentCount, arguments, exception in
    let object = JavaScriptCoreBackendDriver.withConstructorCallbackInput(
      ctx: ctx,
      constructorRef: constructorRef
    ) { definition, context, constructorValue, thisValue in
      let callbackResult: JSPrivateResult = JavaScriptCoreBackendDriver.withArguments(
        arguments,
        count: Int(argumentCount)
      ) { args in
        let result =
          definition.callAsConstructor?(context, &constructorValue, &thisValue, args)
          ?? JSValue(undefinedIn: context)
        guard result.isObject else {
          return .value(JSValue(undefinedIn: context).retainedRef())
        }
        return .value(result.retainedRef())
      }
      return JavaScriptCoreBackendDriver.constructorCallbackReturnValue(
        callbackResult,
        in: ctx,
        exception: exception
      )
    }
    return callbackObjectOrNil(object)
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
    staticValue.attributes = JavaScriptCoreBackendDriver.propertyAttributes(
      from: property.attributes
    )
    backing.staticValues.append(staticValue)
  }
  backing.staticValues.append(JavaScriptCore.JSStaticValue())
  backing.staticValues.withUnsafeBufferPointer {
    cls.staticValues = $0.baseAddress
  }
}

private func installConvertToTypeCallbackIfNeeded(
  _ descriptor: JSHostTypeDescriptor,
  into cls: inout JavaScriptCore.JSClassDefinition
) {
  guard JavaScriptCoreBackendDriver.hasConvertToType(for: descriptor) else {
    return
  }

  cls.convertToType = { ctx, objectRef, type, exception in
    let value = JavaScriptCoreBackendDriver.withConvertToTypeCallbackInput(
      ctx: ctx,
      objectRef: objectRef,
      jsType: JSType(type)
    ) { definition, context, objectValue, jsType, exceptionValue in
      let result =
        definition.convertToType?(context, &objectValue, jsType, &exceptionValue)
        ?? JSValue(undefinedIn: context)
      let exceptionRef: JSValueRef?
      if exceptionValue.isUndefined {
        exceptionRef = nil
      } else {
        exceptionRef = exceptionValue.retainedRef()
        exceptionValue = JSValue(undefinedIn: context)
      }
      let conversion: JSPrivateResult =
        if let exceptionRef {
          .exception(exceptionRef)
        } else {
          .value(result.retainedRef())
        }
      return JavaScriptCoreBackendDriver.callbackReturnValue(
        conversion,
        in: ctx,
        exception: exception
      )
    }
    return callbackValueOrUndefined(value, in: ctx)
  }
}

private let staticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  let value = JavaScriptCoreBackendDriver.withStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    JavaScriptCoreBackendDriver.callbackReturnValue(
      valueDefinition.getProperty(context, thisValue).toPrivateResult(),
      in: ctx,
      exception: exception
    )
  }
  return callbackValueOrUndefined(value, in: ctx)
}

private let staticValueSetPropertyCallback: JSObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let value else {
    return false
  }
  let didSet = JavaScriptCoreBackendDriver.withStaticValueCallbackInput(
    ctx: ctx,
    object: object,
    propertyName: propertyName
  ) { valueDefinition, context, thisValue in
    let newValue = JSValue(ref: value, ctx: context)
    switch valueDefinition.setProperty(context, thisValue, newValue).toPrivateResult() {
    case .value:
      return true
    case .exception(let error):
      return JavaScriptCoreBackendDriver.callbackSucceeded(
        exceptionValue: error,
        exception: exception
      )
    }
  }
  return callbackBoolOrFalse(didSet)
}

private let staticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  let value = JavaScriptCoreBackendDriver.withStaticFunctionCallbackInput(
    ctx: ctx,
    function: function,
    thisObject: thisObject
  ) { functionDefinition, context, thisValue in
    let result = JavaScriptCoreBackendDriver.withArguments(arguments, count: Int(argumentCount)) {
      args in
      functionDefinition.callAsFunction(context, thisValue, args).toPrivateResult()
    }
    return JavaScriptCoreBackendDriver.callbackReturnValue(
      result,
      in: ctx,
      exception: exception
    )
  }
  return callbackValueOrUndefined(value, in: ctx)
}

extension JSClassDefinition {

  fileprivate func manualNativeDefinition(backing: JSManualNativeClassBacking)
    -> JavaScriptCore.JSClassDefinition
  {
    var cls = JavaScriptCore.kJSClassDefinitionEmpty
    let descriptor = JavaScriptCoreBackendDriver.hostTypeDescriptor(for: self)

    cls.version = version
    cls.attributes = attributes.rawValue
    cls.parentClass = parentClass?.ref

    if let className {
      backing.className = className.utf8CString
      backing.className?.withUnsafeBufferPointer {
        cls.className = $0.baseAddress
      }
    }

    installStaticValueMembers(descriptor, backing: backing, into: &cls)

    if !descriptor.methods.isEmpty {
      backing.staticFunctionNames = descriptor.methods.map { $0.name.utf8CString }
      backing.staticFunctions = []
      backing.staticFunctions.reserveCapacity(descriptor.methods.count + 1)
      for (index, method) in descriptor.methods.enumerated() {
        var staticFunction = JavaScriptCore.JSStaticFunction()
        backing.staticFunctionNames[index].withUnsafeBufferPointer {
          staticFunction.name = $0.baseAddress
        }
        staticFunction.callAsFunction = staticFunctionCallAsFunctionCallback
        staticFunction.attributes = JavaScriptCoreBackendDriver.propertyAttributes(
          from: method.attributes)
        backing.staticFunctions.append(staticFunction)
      }
      backing.staticFunctions.append(JavaScriptCore.JSStaticFunction())
      backing.staticFunctions.withUnsafeBufferPointer {
        cls.staticFunctions = $0.baseAddress
      }
    }

    cls.initialize = classInitializeCallback
    cls.finalize = classFinalizeCallback

    installGetPropertyCallbackIfNeeded(descriptor, into: &cls)

    installSetPropertyCallbackIfNeeded(descriptor, into: &cls)

    installHasPropertyCallbackIfNeeded(descriptor, into: &cls)

    installDeletePropertyCallbackIfNeeded(descriptor, into: &cls)

    installPropertyNamesCallbackIfNeeded(descriptor, into: &cls)

    installCallAsFunctionCallbackIfNeeded(descriptor, into: &cls)

    installCallAsConstructorCallbackIfNeeded(descriptor, into: &cls)

    installHasInstanceCallbackIfNeeded(descriptor, into: &cls)

    installConvertToTypeCallbackIfNeeded(descriptor, into: &cls)

    return cls
  }
}

extension JSContext {
  internal static func borrow(ctx: JSContextRef) -> JSContext {
    let context = Unmanaged<JSContext>.fromOpaque(
      JavaScriptCoreBackendDriver.privateData(fromGlobalObjectIn: ctx)!
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

  public init(defination: JSClassDefinition) {
    let backing = JSManualNativeClassBacking()
    var copy = defination.manualNativeDefinition(backing: backing)
    self.ref = JSClassCreate(&copy)
    self.nativeBacking = backing
    rememberClassDefinition(defination, for: ref)
  }

  init(
    nativeDefinition: JavaScriptCore.JSClassDefinition,
    retainedBacking: AnyObject?,
    rememberedDefinition: JSClassDefinition? = nil
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
