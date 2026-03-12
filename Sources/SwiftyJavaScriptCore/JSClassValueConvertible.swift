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
  let definition: JSClassDefinition
  let usesManagedParent: Bool
  var staticValueNames: [ContiguousArray<CChar>] = []
  var staticValues: [JavaScriptCore.JSStaticValue] = []
  var staticFunctionNames: [ContiguousArray<CChar>] = []
  var staticFunctions: [JavaScriptCore.JSStaticFunction] = []

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
    guard value.isObject else {
      throw .typeMismatch(expected: "object", actual: value.type)
    }
    let privateData: UnsafeMutableRawPointer?
    switch JavaScriptCoreBackendDriver.privateData(
      from: value.valueHandle(in: context),
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

    switch JavaScriptCoreBackendDriver.makeObjectResultHandle(
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

  public func toJSValue(in context: borrowing JSInstantContext) -> JSValue {
    Self.encode(self, in: context)
  }

  public func tryEncode(in context: borrowing JSInstantContext) throws(JSValueConversionError)
    -> JSValue
  {
    try Self.tryEncode(self, in: context)
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

private let autoClassInitializeCallback: JSObjectInitializeCallback = { ctx, object in
  guard let ctx, let object,
    let (storage, _) = autoClassStorageRecord(from: object)
  else {
    return
  }

  if let initialize = storage.definition.initialize {
    let context = JSInstantContext(ctx: ctx)
    let this = JSValue(ref: object, ctx: context)
    initialize(this, context)
  }
}

private let autoClassFinalizeCallback: JSObjectFinalizeCallback = { object in
  guard let object,
    let (storage, privateData) = autoClassStorageRecord(from: object)
  else {
    return
  }

  if let finalize = storage.definition.finalize,
    let objectContext = classObjectContext(object)
  {
    let context = JSInstantContext(ctx: objectContext)
    let this = JSValue(ref: object, ctx: context)
    finalize(this)
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
  guard let privateData = JavaScriptCoreBackendDriver.privateData(from: object) else {
    return nil
  }
  let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
  return (storage, privateData)
}

private func autoClassStorage(from object: JSObjectRef) -> JSClassAutoObjectStorage? {
  autoClassStorageRecord(from: object)?.storage
}

private func autoClassDefinition(from object: JSObjectRef) -> JSClassDefinition? {
  autoClassStorage(from: object)?.definition
}

private func withAutoDynamicPropertyCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (JSClassDefinition, borrowing JSInstantContext, borrowing JSValue, String) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return nil
  }

  rememberClassObjectContext(ctx, object)
  let context = JSInstantContext(ctx: ctx)
  let key = String(jsStringRef: propertyName)
  let thisValue = JSValue(ref: object, ctx: context)
  return body(definition, context, thisValue, key)
}

private func withAutoStaticValueCallbackInput<R>(
  ctx: JSContextRef?,
  object: JSObjectRef?,
  propertyName: JSStringRef?,
  _ body: (JSStaticValue, borrowing JSInstantContext, borrowing JSValue) -> R
) -> R? {
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return nil
  }

  rememberClassObjectContext(ctx, object)
  let name = String(jsStringRef: propertyName)
  guard let valueDefinition = inheritedStaticValue(named: name, from: definition) else {
    return nil
  }

  let context = JSInstantContext(ctx: ctx)
  let thisValue = JSValue(ref: object, ctx: context)
  return body(valueDefinition, context, thisValue)
}

private func withAutoStaticFunctionCallbackInput<R>(
  ctx: JSContextRef?,
  function: JSObjectRef?,
  thisObject: JSObjectRef?,
  _ body: (JSStaticFunction, borrowing JSInstantContext, borrowing JSValue) -> R
) -> R? {
  guard let ctx, let function, let thisObject,
    let definition = autoClassDefinition(from: thisObject)
  else {
    return nil
  }

  rememberClassObjectContext(ctx, thisObject)
  let context = JSInstantContext(ctx: ctx)
  let functionValue = JSValue(ref: function, ctx: context)
  let functionName = functionValue.getProperty(forKey: JSStringManaged("name"), in: context)
    .toString(in: context)
  guard let functionDefinition = inheritedStaticFunction(named: functionName, from: definition)
  else {
    return nil
  }

  let thisValue = JSValue(ref: thisObject, ctx: context)
  return body(functionDefinition, context, thisValue)
}

private let autoStaticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  let value = withAutoStaticValueCallbackInput(
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
  guard let value else {
    return JSValueMakeUndefined(ctx)
  }
  return value
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
  guard let didSet else {
    return false
  }
  return didSet
}

private let autoStaticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  let value = withAutoStaticFunctionCallbackInput(
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
  guard let value else {
    return JSValueMakeUndefined(ctx)
  }
  return value
}

private func autoNativeDefinition(backing: JSClassAutoNativeClassBacking)
  -> JavaScriptCore.JSClassDefinition
{
  var cls = JavaScriptCore.kJSClassDefinitionEmpty
  cls.version = backing.definition.version
  cls.attributes = backing.definition.attributes.rawValue
  cls.parentClass = backing.definition.parentClass?.ref
  cls.initialize = autoClassInitializeCallback
  cls.finalize = autoClassFinalizeCallback

  if !backing.definition.staticValues.isEmpty {
    backing.staticValueNames = backing.definition.staticValues.map { $0.name.utf8CString }
    backing.staticValues = []
    backing.staticValues.reserveCapacity(backing.definition.staticValues.count + 1)
    for (index, value) in backing.definition.staticValues.enumerated() {
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

  if !backing.definition.staticFunctions.isEmpty {
    backing.staticFunctionNames = backing.definition.staticFunctions.map { $0.name.utf8CString }
    backing.staticFunctions = []
    backing.staticFunctions.reserveCapacity(backing.definition.staticFunctions.count + 1)
    for (index, function) in backing.definition.staticFunctions.enumerated() {
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

  if backing.definition.getProperty != nil {
    cls.getProperty = { ctx, object, propertyName, exception in
      let value = withAutoDynamicPropertyCallbackInput(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        guard let getProperty = definition.getProperty else {
          return JSValueMakeUndefined(ctx)
        }
        return JavaScriptCoreBackendDriver.callbackReturnValue(
          getProperty(context, thisValue, key).toPrivateResult(),
          in: ctx,
          exception: exception
        )
      }
      guard let value else {
        return JSValueMakeUndefined(ctx)
      }
      return value
    }
  }

  if backing.definition.setProperty != nil {
    cls.setProperty = { ctx, object, propertyName, value, exception in
      guard let value else {
        return false
      }
      let didSet = withAutoDynamicPropertyCallbackInput(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        let newValue = JSValue(ref: value, ctx: context)
        guard let setProperty = definition.setProperty else {
          return true
        }
        if let error = setProperty(context, thisValue, key, newValue)?.retainedRef() {
          return JavaScriptCoreBackendDriver.callbackSucceeded(
            exceptionValue: error,
            exception: exception
          )
        }
        return true
      }
      guard let didSet else {
        return false
      }
      return didSet
    }
  }

  if backing.definition.hasProperty != nil {
    cls.hasProperty = { ctx, object, propertyName in
      let hasProperty = withAutoDynamicPropertyCallbackInput(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        definition.hasProperty?(context, thisValue, key) ?? false
      }
      guard let hasProperty else {
        return false
      }
      return hasProperty
    }
  }

  if backing.definition.deleteProperty != nil {
    cls.deleteProperty = { ctx, object, propertyName, exception in
      let didDelete = withAutoDynamicPropertyCallbackInput(
        ctx: ctx,
        object: object,
        propertyName: propertyName
      ) { definition, context, thisValue, key in
        definition.deleteProperty?(context, thisValue, key) ?? false
      }
      guard let didDelete else {
        return false
      }
      return didDelete
    }
  }

  return cls
}
