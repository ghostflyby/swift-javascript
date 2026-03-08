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
  static func decode(_ value: borrowing JSValue, in context: borrowing JSCallbackContext) -> Self
  static func tryDecode(
    _ value: borrowing JSValue,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> Self
  static func encode(_ value: Self, in context: borrowing JSCallbackContext) -> JSValue
  static func tryEncode(
    _ value: Self,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> JSValue
}

public enum JSClassValueConverter<T: JSClassValueConvertible>: JSValueConverter {
  public typealias SwiftType = T

  public static func decode(_ value: borrowing JSValue, in context: borrowing JSCallbackContext)
    -> T
  {
    T.decode(value, in: context)
  }

  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode(_ value: T, in context: borrowing JSCallbackContext) -> JSValue {
    T.encode(value, in: context)
  }

  public static func tryEncode(
    _ value: T,
    in context: borrowing JSCallbackContext
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

  public static func decode(_ value: borrowing JSValue, in context: borrowing JSCallbackContext)
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
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> Self {
    guard value.isObject else {
      throw .typeMismatch(expected: "object", actual: value.type)
    }

    var exception: JSValueRef?
    guard let object = JSValueToObject(context.globalContextRef, value.ref, &exception) else {
      throw .codable("\(Self.self) could not be converted to JSObjectRef")
    }

    guard let privateData = JSObjectGetPrivate(object) else {
      throw .codable("\(Self.self) does not have a Swift instance backing")
    }

    let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
    guard let instance = storage.instance as? Self else {
      throw .codable("JS object backing is not of type \(Self.self)")
    }

    return instance
  }

  public static func encode(_ value: Self, in context: borrowing JSCallbackContext) -> JSValue {
    do {
      return try tryEncode(value, in: context)
    } catch {
      return JSValue(undefinedIn: context)
    }
  }

  public static func tryEncode(
    _ value: Self,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> JSValue {
    let definition = Self.jsClassDefinition
    let storage = JSClassAutoObjectStorage(
      definition: definition,
      instance: value,
      finalizeDepth: exportedDefinitionCount(definition)
    )
    let data = Unmanaged.passRetained(storage).toOpaque()

    guard let object = JSObjectMake(context.globalContextRef, Self.jsClass.ref, data) else {
      _ = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(data).takeRetainedValue()
      throw .codable("Failed to create JS object for \(Self.self)")
    }

    return JSValue(ref: object, ctx: context)
  }

  public func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
    Self.encode(self, in: context)
  }

  public func tryEncode(in context: borrowing JSCallbackContext) throws(JSValueConversionError)
    -> JSValue
  {
    try Self.tryEncode(self, in: context)
  }
}

extension JSValue {
  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try T.tryDecode(self, in: context)
  }

  public func tryDecode<T: JSClassValueConvertible>(
    as type: T.Type = T.self,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> T {
    _ = type
    return try context.withCallbackContext { callbackContext throws(JSValueConversionError) in
      try T.tryDecode(self, in: callbackContext)
    }
  }
}

private let autoClassInitializeCallback: JSObjectInitializeCallback = { ctx, object in
  guard let ctx, let object, let privateData = JSObjectGetPrivate(object) else {
    return
  }

  let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
  if let initialize = storage.definition.initialize {
    let context = JSCallbackContext(ctx: ctx)
    let this = JSValue(ref: object, ctx: context)
    initialize(this, context)
  }
}

private let autoClassFinalizeCallback: JSObjectFinalizeCallback = { object in
  guard let object, let privateData = JSObjectGetPrivate(object) else {
    return
  }

  let storage = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
  if let finalize = storage.definition.finalize,
    let objectContext = classObjectContext(object)
  {
    let context = JSCallbackContext(ctx: objectContext)
    let this = JSValue(ref: object, ctx: context)
    finalize(this)
  }

  let remaining = storage.finalizeDepth - 1
  if remaining <= 0 {
    removeClassObjectContext(object)
    _ = Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeRetainedValue()
  }
}

private func autoClassStorage(from object: JSObjectRef) -> JSClassAutoObjectStorage? {
  guard let privateData = JSObjectGetPrivate(object) else {
    return nil
  }
  return Unmanaged<JSClassAutoObjectStorage>.fromOpaque(privateData).takeUnretainedValue()
}

private func autoClassDefinition(from object: JSObjectRef) -> JSClassDefinition? {
  autoClassStorage(from: object)?.definition
}

private func withAutoJSArguments<R>(
  _ arguments: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSArguments) -> R
) -> R {
  if let arguments {
    return body(JSArguments(pointer: arguments, count: count))
  }
  var empty: JSValueRef? = nil
  return withUnsafePointer(to: &empty) { pointer in
    body(JSArguments(pointer: pointer, count: count))
  }
}

private let autoStaticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  guard let ctx, let object, let propertyName,
    let definition = autoClassDefinition(from: object)
  else {
    return JSValueMakeUndefined(ctx)
  }
  rememberClassObjectContext(ctx, object)

  let name = String(jsStringRef: propertyName)
  guard let valueDef = inheritedStaticValue(named: name, from: definition) else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSCallbackContext(ctx: ctx)
  let this = JSValue(ref: object, ctx: context)
  let result = valueDef.getProperty(context, this).toPrivateResult()

  switch result {
  case .value(let value):
    return value
  case .exception(let error):
    exception?.pointee = error
    return JSValueMakeUndefined(ctx)
  }
}

private let autoStaticValueSetPropertyCallback: JSObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let ctx, let object, let propertyName, let value,
    let definition = autoClassDefinition(from: object)
  else {
    return false
  }
  rememberClassObjectContext(ctx, object)

  let name = String(jsStringRef: propertyName)
  guard let valueDef = inheritedStaticValue(named: name, from: definition) else {
    return false
  }

  let context = JSCallbackContext(ctx: ctx)
  let this = JSValue(ref: object, ctx: context)
  let newValue = JSValue(ref: value, ctx: context)
  let result = valueDef.setProperty(context, this, newValue).toPrivateResult()

  switch result {
  case .value:
    return true
  case .exception(let error):
    exception?.pointee = error
    return false
  }
}

private let autoStaticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function,
    let thisObjectRef = thisObject,
    let definition = autoClassDefinition(from: thisObjectRef)
  else {
    return JSValueMakeUndefined(ctx)
  }

  rememberClassObjectContext(ctx, thisObjectRef)

  let nameKey = JSStringManaged("name")
  let functionNameValue = JSObjectGetProperty(ctx, function, nameKey.ref, nil)
  let functionName = functionNameValue.flatMap { value -> String? in
    guard let nameRef = JSValueToStringCopy(ctx, value, nil) else {
      return nil
    }
    defer { JSStringRelease(nameRef) }
    return String(jsStringRef: nameRef)
  }

  guard let functionName,
    let functionDef = inheritedStaticFunction(named: functionName, from: definition)
  else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSCallbackContext(ctx: ctx)
  let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
  let thisValue = JSValue(ref: thisObjectRef, ctx: context)
  let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
  let result = withAutoJSArguments(argumentsPointer, count: Int(argumentCount)) { args in
    functionDef.callAsFunction(context, thisValue, args).toPrivateResult()
  }

  switch result {
  case .value(let value):
    return value
  case .exception(let error):
    exception?.pointee = error
    return JSValueMakeUndefined(ctx)
  }
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
      guard let ctx, let object, let propertyName,
        let definition = autoClassDefinition(from: object)
      else {
        return JSValueMakeUndefined(ctx)
      }
      rememberClassObjectContext(ctx, object)
      let context = JSCallbackContext(ctx: ctx)
      let key = String(jsStringRef: propertyName)
      let this = JSValue(ref: object, ctx: context)
      let result = definition.getProperty?(context, this, key).toPrivateResult()
      switch result {
      case .some(.value(let value)):
        return value
      case .some(.exception(let error)):
        exception?.pointee = error
        return JSValueMakeUndefined(ctx)
      case .none:
        return JSValueMakeUndefined(ctx)
      }
    }
  }

  if backing.definition.setProperty != nil {
    cls.setProperty = { ctx, object, propertyName, value, exception in
      guard let ctx, let object, let propertyName, let value,
        let definition = autoClassDefinition(from: object)
      else {
        return false
      }
      rememberClassObjectContext(ctx, object)
      let context = JSCallbackContext(ctx: ctx)
      let key = String(jsStringRef: propertyName)
      let this = JSValue(ref: object, ctx: context)
      let newValue = JSValue(ref: value, ctx: context)
      if let error = definition.setProperty?(context, this, key, newValue)?.retainedRef() {
        exception?.pointee = error
        return false
      }
      return true
    }
  }

  if backing.definition.hasProperty != nil {
    cls.hasProperty = { ctx, object, propertyName in
      guard let ctx, let object, let propertyName,
        let definition = autoClassDefinition(from: object)
      else {
        return false
      }
      rememberClassObjectContext(ctx, object)
      let context = JSCallbackContext(ctx: ctx)
      let key = String(jsStringRef: propertyName)
      let this = JSValue(ref: object, ctx: context)
      return definition.hasProperty?(context, this, key) ?? false
    }
  }

  if backing.definition.deleteProperty != nil {
    cls.deleteProperty = { ctx, object, propertyName, exception in
      guard let ctx, let object, let propertyName,
        let definition = autoClassDefinition(from: object)
      else {
        return false
      }
      rememberClassObjectContext(ctx, object)
      let context = JSCallbackContext(ctx: ctx)
      let key = String(jsStringRef: propertyName)
      let this = JSValue(ref: object, ctx: context)
      return definition.deleteProperty?(context, this, key) ?? false
    }
  }

  return cls
}
