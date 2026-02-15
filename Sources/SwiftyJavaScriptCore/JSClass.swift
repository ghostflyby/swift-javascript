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
    @Sendable (isolated JSContext, borrowing JSValue, Span<JSValue>) -> JSResult
}

public struct JSClassDefinition: Sendable {

  public var version: Int32 = 0

  public var attributes: JSClassAttributes = .none

  public var className: String? {
    didSet {
      if let oldValue = oldValue {
        _className = oldValue.utf8CString
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
    (@Sendable (isolated JSContext, inout JSValue, inout JSValue, Span<JSValue>) -> JSValue)? = nil

  public var callAsConstructor:
    (@Sendable (isolated JSContext, inout JSValue, inout JSValue, Span<JSValue>) -> JSValue)? = nil

  public var hasInstance: (@Sendable (isolated JSContext, inout JSValue, inout JSValue) -> Bool)? =
    nil

  public var convertToType:
    (@Sendable (isolated JSContext, inout JSValue, JSType, inout JSValue) -> JSValue)? = nil
}

protocol JSClassType {
  var definition: JSClassDefinition { get }
}

extension JSClassDefinition {

  func toNative() -> JavaScriptCore.JSClassDefinition {
    var cls = JavaScriptCore.kJSClassDefinitionEmpty

    cls.version = version
    cls.attributes = attributes.rawValue

    _className?.withUnsafeBufferPointer {
      cls.className = $0.baseAddress
    }

    if initialize != nil {
      cls.initialize = { ctx, object in
        let context = JSContext.borrow(ctx: ctx!)
        let type = Unmanaged<Box<JSClassDefinition>>.fromOpaque(JSObjectGetPrivate(object)!)
          .takeUnretainedValue().value
        let this = SendableBoxUnsafe(object!)
        context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          type.initialize!(this, context)
        }
      }
    }

    if getProperty != nil {
      cls.getProperty = { ctx, object, propertyName, exception in
        let context = JSContext.borrow(ctx: ctx!)
        let obj = SendableBoxUnsafe(object!)
        let type = Unmanaged<Box<any JSClassType>>.fromOpaque(JSObjectGetPrivate(object)!)
          .takeUnretainedValue().value

        let def = type.definition

        let s = String(jsStringRef: propertyName!)
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
        let context = JSContext.borrow(ctx: ctx!)
        let this = SendableBoxUnsafe(object!)
        let value = SendableBoxUnsafe(value!)
        let type = Unmanaged<Box<JSClassDefinition>>.fromOpaque(JSObjectGetPrivate(object)!)
          .takeUnretainedValue().value
        let s = String(jsStringRef: propertyName!)
        let setResult = context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          let value = JSValue(ref: value.value, ctx: context)
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
        let context = JSContext.borrow(ctx: ctx!)
        let this = SendableBoxUnsafe(object!)
        let type = Unmanaged<Box<JSClassDefinition>>.fromOpaque(JSObjectGetPrivate(object)!)
          .takeUnretainedValue().value
        let s = String(jsStringRef: propertyName!)
        return context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          return type.hasProperty!(context, this, s)
        }
      }
    }

    if deleteProperty != nil {
      cls.deleteProperty = { ctx, object, propertyName, exception in
        let context = JSContext.borrow(ctx: ctx!)
        let this = SendableBoxUnsafe(object!)
        let type = Unmanaged<Box<JSClassDefinition>>.fromOpaque(JSObjectGetPrivate(object)!)
          .takeUnretainedValue().value
        let s = String(jsStringRef: propertyName!)
        let deleteResult = context.assumeIsolated { context in
          let this = JSValue(ref: this.value, ctx: context)
          return type.deleteProperty!(context, this, s)
        }
        return deleteResult
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

  public init(ref: JSClassRef) {
    self.ref = JSClassRetain(ref)
  }

  public init(defination: JSClassDefinition) {
    var copy = defination.toNative()
    self.ref = JSClassCreate(&copy)
  }

  deinit {
    JSClassRelease(ref)
  }
}
