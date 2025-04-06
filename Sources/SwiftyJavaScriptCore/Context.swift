import JavaScriptCore

public protocol JSContextGroupProtocol: ~Copyable {
  var ref: JSContextGroupRef { get }
  init(ref: JSContextGroupRef)
}

extension JSContextGroupProtocol {
  public init(group: borrowing some JSContextGroupProtocol) {
    self.init(ref: group.ref)
  }
  public init() {
    self.init(ref: JSContextGroupCreate())
  }
}

extension JSContextGroupProtocol {
  public func createContext() -> JSContext {
    JSContext(group: self)
  }

  public func createContext(
    globalClass: borrowing JSClassValue
  ) -> JSContext {
    JSContext(group: self, globalClass: globalClass)
  }
}

public final class JSContextGroup: @unchecked Sendable, JSContextGroupProtocol {

  public let ref: JSContextGroupRef

  public init(ref: JSContextGroupRef) {
    self.ref = JSContextGroupRetain(ref)
  }

  deinit {
    JSContextGroupRelease(ref)
  }
}

@frozen
public struct JSContextGroupValue: ~Copyable, @unchecked Sendable, JSContextGroupProtocol,
  TransferableCopy
{
  public let ref: JSContextGroupRef

  public init(ref: JSContextGroupRef) {
    self.ref = JSContextGroupRetain(ref)
  }

  public init(copying group: borrowing JSContextGroupValue) {
    self.ref = group.ref
  }

  deinit {
    JSContextGroupRelease(ref)
  }
}

@frozen
public struct JSContext: ~Copyable, @unchecked Sendable {
  public let ref: JSGlobalContextRef

  public init() {
    self.ref = JSGlobalContextCreate(nil)
  }

  public init(globalClass jsClass: borrowing JSClassValue) {
    self.ref = JSGlobalContextCreate(jsClass.ref)
  }

  public init(group: borrowing some JSContextGroupProtocol, globalClass: borrowing JSClassValue) {
    self.ref =
      JSGlobalContextCreateInGroup(group.ref, globalClass.ref)
  }

  public init(group: borrowing some JSContextGroupProtocol) {
    self.ref = JSGlobalContextCreateInGroup(group.ref, nil)
  }

  deinit {
    JSGlobalContextRelease(ref)
  }

}

extension JSContext {

  @available(macOS 13.3, *)
  public var isInspectable: Bool {
    get { JSGlobalContextIsInspectable(ref) }
    set { JSGlobalContextSetInspectable(ref, newValue) }
  }

  public var name: String {
    get {
      guard let name = JSGlobalContextCopyName(ref) else {
        return ""
      }
      return String(jsStringRef: name)
    }
    set {
      JSGlobalContextSetName(ref, JSStringValue(newValue).ref)
    }
  }

  public var group: JSContextGroupValue {
    JSContextGroupValue(ref: JSContextGetGroup(ref)!)
  }
}
