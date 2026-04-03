extension String {
  public init(jsStringRef: JavaScriptCoreStringRef) {
    let length = JavaScriptCoreEngine.stringLength(jsStringRef)
    let characters = JavaScriptCoreEngine.stringCharacters(jsStringRef)!
    self = String(utf16CodeUnits: characters, count: length)
  }
}

public protocol JSString: ~Copyable {
  var ref: JavaScriptCoreStringRef { get }
  var cached: String? { get }
  var string: String { get }
  init(ref: JavaScriptCoreStringRef)
  init(_ string: String)
}

extension JSString {
  public init(group: borrowing some JSString) {
    self.init(ref: group.ref)
  }
}

extension JSString {
  public static func == (lhs: borrowing Self, rhs: borrowing some JSString) -> Bool {
    JavaScriptCoreEngine.stringEquals(lhs.ref, rhs.ref)
  }

  public static func != (lhs: borrowing Self, rhs: borrowing some JSString) -> Bool {
    !(lhs == rhs)
  }

}

public final class JSStringManaged: @unchecked Sendable, JSString {

  public static let empty = JSStringManaged("")

  public let ref: JavaScriptCoreStringRef
  public var cached: String? { string }
  public let string: String

  public init(ref: JavaScriptCoreStringRef) {
    self.ref = JavaScriptCoreEngine.retain(ref)
    string = String(jsStringRef: ref)
  }

  public init(_ string: String) {
    ref = JavaScriptCoreEngine.makeJSString(string)
    self.string = string
  }

  deinit {
    JavaScriptCoreEngine.release(ref)
  }
}

public struct JSStringValue: @unchecked Sendable, ~Copyable, JSString {

  public let ref: JavaScriptCoreStringRef
  public let cached: String?
  public var string: String {
    cached
      ?? String(jsStringRef: ref)
  }

  public init(ref: JavaScriptCoreStringRef) {
    self.ref = JavaScriptCoreEngine.retain(ref)
    cached = nil
  }

  public init(_ string: String) {
    ref = JavaScriptCoreEngine.makeJSString(string)
    self.cached = string
  }

  public init(_ string: borrowing JSStringValue, caching: Bool = false) {
    ref = JavaScriptCoreEngine.retain(string.ref)
    self.cached =
      if caching {
        string.string
      } else {
        string.cached
      }
  }

  public init(_ string: borrowing some JSString, caching: Bool = false) {
    ref = JavaScriptCoreEngine.retain(string.ref)
    self.cached =
      if caching {
        string.string
      } else {
        nil
      }
  }

  deinit {
    JavaScriptCoreEngine.release(ref)
  }
}

extension JSStringValue: TransferableCopy {
  public init(copying string: borrowing JSStringValue) {
    self.init(string, caching: false)
  }
}
