import JavaScriptCore

public typealias JSClassDefinition = JavaScriptCore.JSClassDefinition

public struct MyJSClassDefinition {

  public struct MyJSClassAttributes: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    public static let none = MyJSClassAttributes(rawValue: kJSClassAttributeNone)
    public static let noAutomaticPrototype = MyJSClassAttributes(
      rawValue: kJSClassAttributeNoAutomaticPrototype)
  }

  public let version: Int32

  public let attributes: MyJSClassAttributes

  public let className: String

  public let parentClass: JSClassManaged

  public let staticValues: [JSStaticValue]

  public let staticFunctions: [JSStaticFunction]

  public let initialize: (inout JSContext, inout JSValue) -> Void

  public let finalize: (inout JSValue) -> Void

  public let hasProperty: (inout JSContext, inout JSValue, inout JSString) -> Bool

  public let getProperty: (inout JSContext, inout JSValue, inout JSString, inout JSValue) -> Void

  public let setProperty:
    (inout JSContext, inout JSValue, inout JSString, inout JSValue, inout JSValue) -> Void
  public let deleteProperty: (inout JSContext, inout JSValue, inout JSString) -> Bool

  public let getPropertyNames:
    (inout JSContext, inout JSValue, JSPropertyNameAccumulatorRef) -> Void

  public let callAsFunction:
    (inout JSContext, inout JSValue, inout JSValue, Int, UnsafePointer<JSValue>) -> JSValue

  public let callAsConstructor:
    (inout JSContext, inout JSValue, inout JSValue, Int, UnsafePointer<JSValue>) -> JSValue

  public let hasInstance: (inout JSContext, inout JSValue, inout JSValue) -> Bool
  public let convertToType: (inout JSContext, inout JSValue, JSType, inout JSValue) -> JSValue
}

public class JSClassManaged: @unchecked Sendable {
  public let ref: JSClassRef

  public init(ref: JSClassRef) {
    self.ref = JSClassRetain(ref)
  }

  public init(defination: JSClassDefinition) {
    var copy = defination
    self.ref = JSClassCreate(&copy)
  }

  deinit {
    JSClassRelease(ref)
  }
}

@frozen
public struct JSClassValue: @unchecked Sendable, ~Copyable, TransferableCopy {
  public let ref: JSClassRef

  public init(defination: JSClassDefinition) {
    var copy = defination
    self.ref = JSClassCreate(&copy)
  }

  public init(copying other: borrowing Self) {
    ref = JSClassRetain(other.ref)
  }
  deinit {
    JSClassRelease(ref)
  }
}
