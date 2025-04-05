import JavaScriptCore

public typealias JSClassDefinition = JavaScriptCore.JSClassDefinition

public class JSClassClass: @unchecked Sendable {
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
public struct JSClass: @unchecked Sendable, ~Copyable, TransferableCopy {
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
