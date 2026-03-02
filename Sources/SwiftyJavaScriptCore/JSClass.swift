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
  public let getProperty: @Sendable (isolated JSContext, borrowing JSValue) -> JSResult
  public let setProperty:
    @Sendable (isolated JSContext, borrowing JSValue, borrowing JSValue) -> JSResult
}

public struct JSStaticFunction: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let callAsFunction:
    @Sendable (isolated JSContext, borrowing JSValue, borrowing JSArguments) -> JSResult
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

  public var initialize: (@Sendable (borrowing JSValue, isolated JSContext) -> Void)? = nil

  public var finalize: (@Sendable (borrowing JSValue) -> Void)? = nil

  public var hasProperty: (@Sendable (isolated JSContext, borrowing JSValue, String) -> Bool)? = nil

  public var getProperty: (@Sendable (isolated JSContext, borrowing JSValue, String) -> JSResult)? =
    nil

  public var setProperty:
    (@Sendable (isolated JSContext, borrowing JSValue, String, borrowing JSValue) -> JSValue?)? =
      nil

  public var deleteProperty: (@Sendable (isolated JSContext, borrowing JSValue, String) -> Bool)? =
    nil

  public var getPropertyNames:
    (@Sendable (isolated JSContext, inout JSValue, JSPropertyNameAccumulatorRef) -> Void)? = nil

  public var callAsFunction:
    (
      @Sendable (isolated JSContext, inout JSValue, inout JSValue, borrowing JSArguments) -> JSValue
    )? = nil

  public var callAsConstructor:
    (
      @Sendable (isolated JSContext, inout JSValue, inout JSValue, borrowing JSArguments) -> JSValue
    )? = nil

  public var hasInstance: (@Sendable (isolated JSContext, inout JSValue, inout JSValue) -> Bool)? =
    nil

  public var convertToType:
    (@Sendable (isolated JSContext, inout JSValue, JSType, inout JSValue) -> JSValue)? = nil
}

private final class JSNativeClassBacking {
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

private func withJSArguments<R>(
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

private func classObjectKey(_ object: JSObjectRef) -> UInt {
  UInt(bitPattern: object)
}

private func rememberClassObjectContext(_ ctx: JSContextRef, _ object: JSObjectRef) {
  classObjectContextRegistry.set(object, context: ctx)
}

private func classObjectContext(_ object: JSObjectRef) -> JSContextRef? {
  classObjectContextRegistry.get(object)
}

private func removeClassObjectContext(_ object: JSObjectRef) {
  classObjectContextRegistry.remove(object)
}

private func classDefinition(from object: JSObjectRef) -> JSClassDefinition? {
  guard let pointer = JSObjectGetPrivate(object) else {
    return nil
  }
  return Unmanaged<Box<JSClassDefinition>>.fromOpaque(pointer).takeUnretainedValue().value
}

private let staticValueGetPropertyCallback: JSObjectGetPropertyCallback = {
  ctx, object, propertyName, exception in
  guard let ctx, let object, let propertyName,
    let definition = classDefinition(from: object)
  else {
    return JSValueMakeUndefined(ctx)
  }
  rememberClassObjectContext(ctx, object)

  let name = String(jsStringRef: propertyName)
  guard let valueDef = definition.staticValues.first(where: { $0.name == name }) else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSContext.borrow(ctx: ctx)
  let boxedObject = SendableBoxUnsafe(object)
  let result = context.assumeIsolated { context in
    let this = JSValue(ref: boxedObject.value, ctx: context)
    return valueDef.getProperty(context, this).toPrivateResult()
  }
  switch result {
  case .value(let value):
    return value
  case .exception(let error):
    exception?.pointee = error
    return JSValueMakeUndefined(ctx)
  }
}

private let staticValueSetPropertyCallback: JSObjectSetPropertyCallback = {
  ctx, object, propertyName, value, exception in
  guard let ctx, let object, let propertyName, let value,
    let definition = classDefinition(from: object)
  else {
    return false
  }
  rememberClassObjectContext(ctx, object)

  let name = String(jsStringRef: propertyName)
  guard let valueDef = definition.staticValues.first(where: { $0.name == name }) else {
    return false
  }

  let context = JSContext.borrow(ctx: ctx)
  let boxedObject = SendableBoxUnsafe(object)
  let boxedValue = SendableBoxUnsafe(value)
  let result = context.assumeIsolated { context in
    let this = JSValue(ref: boxedObject.value, ctx: context)
    let newValue = JSValue(ref: boxedValue.value, ctx: context)
    return valueDef.setProperty(context, this, newValue).toPrivateResult()
  }

  switch result {
  case .value:
    return true
  case .exception(let error):
    exception?.pointee = error
    return false
  }
}

private let staticFunctionCallAsFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function,
    let thisObjectRef = thisObject,
    let definition = classDefinition(from: thisObjectRef)
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
    let functionDef = definition.staticFunctions.first(where: { $0.name == functionName })
  else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSContext.borrow(ctx: ctx)
  let boxedThisObject = SendableBoxUnsafe(thisObjectRef)
  let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
  let result = context.assumeIsolated { context in
    let thisValue = JSValue(ref: boxedThisObject.value, ctx: context)
    let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
    return withJSArguments(argumentsPointer, count: Int(argumentCount)) { args in
      functionDef.callAsFunction(context, thisValue, args).toPrivateResult()
    }
  }

  switch result {
  case .value(let value):
    return value
  case .exception(let error):
    exception?.pointee = error
    return JSValueMakeUndefined(ctx)
  }
}

extension JSClassDefinition {

  fileprivate func toNative(backing: JSNativeClassBacking) -> JavaScriptCore.JSClassDefinition {
    var cls = JavaScriptCore.kJSClassDefinitionEmpty

    cls.version = version
    cls.attributes = attributes.rawValue
    cls.parentClass = parentClass?.ref

    if let className {
      backing.className = className.utf8CString
      backing.className?.withUnsafeBufferPointer {
        cls.className = $0.baseAddress
      }
    }

    if !staticValues.isEmpty {
      backing.staticValueNames = staticValues.map { $0.name.utf8CString }
      backing.staticValues = []
      backing.staticValues.reserveCapacity(staticValues.count + 1)
      for (index, value) in staticValues.enumerated() {
        var staticValue = JavaScriptCore.JSStaticValue()
        backing.staticValueNames[index].withUnsafeBufferPointer {
          staticValue.name = $0.baseAddress
        }
        staticValue.getProperty = staticValueGetPropertyCallback
        staticValue.setProperty = staticValueSetPropertyCallback
        staticValue.attributes = value.attributes.rawValue
        backing.staticValues.append(staticValue)
      }
      backing.staticValues.append(JavaScriptCore.JSStaticValue())
      backing.staticValues.withUnsafeBufferPointer {
        cls.staticValues = $0.baseAddress
      }
    }

    if !staticFunctions.isEmpty {
      backing.staticFunctionNames = staticFunctions.map { $0.name.utf8CString }
      backing.staticFunctions = []
      backing.staticFunctions.reserveCapacity(staticFunctions.count + 1)
      for (index, function) in staticFunctions.enumerated() {
        var staticFunction = JavaScriptCore.JSStaticFunction()
        backing.staticFunctionNames[index].withUnsafeBufferPointer {
          staticFunction.name = $0.baseAddress
        }
        staticFunction.callAsFunction = staticFunctionCallAsFunctionCallback
        staticFunction.attributes = function.attributes.rawValue
        backing.staticFunctions.append(staticFunction)
      }
      backing.staticFunctions.append(JavaScriptCore.JSStaticFunction())
      backing.staticFunctions.withUnsafeBufferPointer {
        cls.staticFunctions = $0.baseAddress
      }
    }

    if initialize != nil || finalize != nil {
      cls.initialize = { ctx, object in
        guard let ctx, let object,
          let type = classDefinition(from: object)
        else {
          return
        }
        rememberClassObjectContext(ctx, object)
        guard let initialize = type.initialize else {
          return
        }
        let context = JSContext.borrow(ctx: ctx)
        let this = SendableBoxUnsafe(object)
        context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          initialize(this, context)
        }
      }
    }

    if finalize != nil {
      cls.finalize = { object in
        guard let object,
          let type = classDefinition(from: object),
          let finalize = type.finalize,
          let objectContext = classObjectContext(object)
        else {
          if let object {
            removeClassObjectContext(object)
          }
          return
        }
        let context = JSContext.borrow(ctx: objectContext)
        let this = SendableBoxUnsafe(object)
        context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          finalize(this)
        }
        removeClassObjectContext(object)
      }
    }

    if getProperty != nil {
      cls.getProperty = { ctx, object, propertyName, exception in
        guard let ctx, let object, let propertyName,
          let def = classDefinition(from: object)
        else {
          return JSValueMakeUndefined(ctx)
        }
        rememberClassObjectContext(ctx, object)
        let context = JSContext.borrow(ctx: ctx)
        let obj = SendableBoxUnsafe(object)

        let s = String(jsStringRef: propertyName)
        let p = context.assumeIsolated { context in
          let value = JSValue(ref: obj.value, ctx: context)
          return def.getProperty!(context, value, s).toPrivateResult()
        }

        switch p {
        case .value(let v):
          return v
        case .exception(let e):
          exception?.pointee = e
          return JSValueMakeUndefined(ctx)
        }

      }
    }

    if setProperty != nil {
      cls.setProperty = { ctx, object, propertyName, value, exception in
        guard let ctx, let object, let propertyName, let value,
          let type = classDefinition(from: object)
        else {
          return false
        }
        rememberClassObjectContext(ctx, object)
        let context = JSContext.borrow(ctx: ctx)
        let this = SendableBoxUnsafe(object)
        let newValue = SendableBoxUnsafe(value)
        let s = String(jsStringRef: propertyName)
        let setResult = context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          let value = JSValue(ref: newValue.value, ctx: context)
          let setResult = type.setProperty!(context, this, s, value)
          let ref: JSValueRef? =
            if let setResult = setResult {
              setResult.retainedRef()
            } else {
              nil
            }
          return SendableBoxUnsafe(ref)
        }

        if let error = setResult.value {
          exception?.pointee = error
          return false
        }

        return true
      }
    }

    if hasProperty != nil {
      cls.hasProperty = { ctx, object, propertyName in
        guard let ctx, let object, let propertyName,
          let type = classDefinition(from: object)
        else {
          return false
        }
        rememberClassObjectContext(ctx, object)
        let context = JSContext.borrow(ctx: ctx)
        let this = SendableBoxUnsafe(object)
        let s = String(jsStringRef: propertyName)
        return context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          return type.hasProperty!(context, this, s)
        }
      }
    }

    if deleteProperty != nil {
      cls.deleteProperty = { ctx, object, propertyName, exception in
        guard let ctx, let object, let propertyName,
          let type = classDefinition(from: object)
        else {
          return false
        }
        rememberClassObjectContext(ctx, object)
        let context = JSContext.borrow(ctx: ctx)
        let this = SendableBoxUnsafe(object)
        let s = String(jsStringRef: propertyName)
        let deleteResult = context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          return type.deleteProperty!(context, this, s)
        }
        return deleteResult
      }
    }

    if getPropertyNames != nil {
      cls.getPropertyNames = { ctx, object, accumulator in
        guard let ctx, let object, let accumulator,
          let type = classDefinition(from: object)
        else {
          return
        }
        rememberClassObjectContext(ctx, object)
        let context = JSContext.borrow(ctx: ctx)
        let boxedObject = SendableBoxUnsafe(object)
        let boxedAccumulator = SendableBoxUnsafe(accumulator)
        context.assumeIsolated { context in
          var this = JSValue(ref: boxedObject.value, ctx: context)
          type.getPropertyNames?(context, &this, boxedAccumulator.value)
        }
      }
    }

    if callAsFunction != nil {
      cls.callAsFunction = {
        ctx, functionRef, thisObjectRef, argumentCount, arguments, exception in
        guard let ctx, let functionRef, let thisObjectRef,
          let type = classDefinition(from: thisObjectRef)
        else {
          return JSValueMakeUndefined(ctx)
        }
        rememberClassObjectContext(ctx, thisObjectRef)
        let context = JSContext.borrow(ctx: ctx)
        let function = SendableBoxUnsafe(functionRef)
        let thisObject = SendableBoxUnsafe(thisObjectRef)
        let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
        let callbackResult: JSPrivateResult = context.assumeIsolated { context in
          var functionValue = JSValue(ref: function.value, ctx: context)
          var thisValue = JSValue(ref: thisObject.value, ctx: context)
          let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
          return withJSArguments(argumentsPointer, count: Int(argumentCount)) { args in
            let result =
              type.callAsFunction?(context, &functionValue, &thisValue, args)
              ?? JSValue(undefinedIn: context)
            return .value(result.retainedRef())
          }
        }
        switch callbackResult {
        case .value(let value):
          return value
        case .exception(let e):
          exception?.pointee = e
          return JSValueMakeUndefined(ctx)
        }
      }
    }

    if callAsConstructor != nil {
      cls.callAsConstructor = {
        ctx, constructorRef, argumentCount, arguments, exception in
        guard let ctx, let constructorRef,
          let type = classDefinition(from: constructorRef)
        else {
          return nil
        }
        rememberClassObjectContext(ctx, constructorRef)
        let context = JSContext.borrow(ctx: ctx)
        let constructor = SendableBoxUnsafe(constructorRef)
        let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
        let callbackResult: JSPrivateResult = context.assumeIsolated { context in
          var constructorValue = JSValue(ref: constructor.value, ctx: context)
          var thisValue = JSValue(undefinedIn: context)
          let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
          return withJSArguments(argumentsPointer, count: Int(argumentCount)) { args in
            let result =
              type.callAsConstructor?(context, &constructorValue, &thisValue, args)
              ?? JSValue(undefinedIn: context)
            guard result.isObject else {
              return .value(JSValue(undefinedIn: context).retainedRef())
            }
            return .value(result.retainedRef())
          }
        }
        switch callbackResult {
        case .value(let value):
          if JSValueIsObject(ctx, value) {
            return unsafeBitCast(value, to: JSObjectRef?.self)
          }
          return nil
        case .exception(let e):
          exception?.pointee = e
          return nil
        }
      }
    }

    if hasInstance != nil {
      cls.hasInstance = { ctx, constructorRef, possibleInstanceRef, exception in
        guard let ctx, let constructorRef, let possibleInstanceRef,
          let type = classDefinition(from: constructorRef)
        else {
          return false
        }
        rememberClassObjectContext(ctx, constructorRef)
        let context = JSContext.borrow(ctx: ctx)
        let constructor = SendableBoxUnsafe(constructorRef)
        let possibleInstance = SendableBoxUnsafe(possibleInstanceRef)
        return context.assumeIsolated { context in
          var constructorValue = JSValue(ref: constructor.value, ctx: context)
          var possibleInstanceValue = JSValue(ref: possibleInstance.value, ctx: context)
          return type.hasInstance?(context, &constructorValue, &possibleInstanceValue) ?? false
        }
      }
    }

    if convertToType != nil {
      cls.convertToType = { ctx, objectRef, type, exception in
        guard let ctx, let objectRef,
          let callbackOwner = classDefinition(from: objectRef)
        else {
          return JSValueMakeUndefined(ctx)
        }
        rememberClassObjectContext(ctx, objectRef)
        let context = JSContext.borrow(ctx: ctx)
        let object = SendableBoxUnsafe(objectRef)
        let jsType = JSType(type)
        let conversion: JSPrivateResult = context.assumeIsolated { context in
          var objectValue = JSValue(ref: object.value, ctx: context)
          var exceptionValue = JSValue(undefinedIn: context)
          let result =
            callbackOwner.convertToType?(context, &objectValue, jsType, &exceptionValue)
            ?? JSValue(undefinedIn: context)
          if !exceptionValue.isUndefined {
            return .exception(exceptionValue.retainedRef())
          }
          return .value(result.retainedRef())
        }
        switch conversion {
        case .value(let value):
          return value
        case .exception(let e):
          exception?.pointee = e
          return JSValueMakeUndefined(ctx)
        }
      }
    }

    return cls
  }
}

extension JSContext {
  internal static func borrow(ctx: JSContextRef) -> JSContext {
    let context = Unmanaged<JSContext>.fromOpaque(
      JSObjectGetPrivate(JSContextGetGlobalObject(ctx))!
    )
    .takeUnretainedValue()
    return context
  }
}

public class JSClass: @unchecked Sendable {
  public let ref: JSClassRef
  private let nativeBacking: JSNativeClassBacking?

  public init(ref: JSClassRef) {
    self.ref = JSClassRetain(ref)
    self.nativeBacking = nil
  }

  public init(defination: JSClassDefinition) {
    let backing = JSNativeClassBacking()
    var copy = defination.toNative(backing: backing)
    self.ref = JSClassCreate(&copy)
    self.nativeBacking = backing
  }

  deinit {
    JSClassRelease(ref)
  }
}
