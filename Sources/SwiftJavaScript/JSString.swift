public protocol JSString: ~Copyable {
  var cached: String? { get }
  var string: String { get }
  init(_ string: String)
}

extension String {
  public init<E: JSEngine>(jsStringHandle: E.StringHandle, engine _: E.Type = E.self) {
    let length = E.stringLength(jsStringHandle)
    let characters = E.stringCharacters(jsStringHandle)!
    self = String(decoding: UnsafeBufferPointer(start: characters, count: length), as: UTF16.self)
  }
}

extension JSString {
  public init(group: borrowing some JSString) {
    self.init(group.string)
  }
}

extension JSString {
  public static func == (lhs: borrowing Self, rhs: borrowing some JSString) -> Bool {
    lhs.string == rhs.string
  }

  public static func != (lhs: borrowing Self, rhs: borrowing some JSString) -> Bool {
    !(lhs == rhs)
  }
}

public final class JSStringManaged<E: JSEngine>: @unchecked Sendable, JSString {
  public static var empty: JSStringManaged<E> { JSStringManaged("") }

  package let handle: E.StringHandle
  public var jsStringHandle: E.StringHandle { handle }
  public var cached: String? { string }
  public let string: String

  public init(handle: E.StringHandle) {
    _ = handle.retainReference()
    self.handle = handle
    string = String(jsStringHandle: handle, engine: E.self)
  }

  public convenience init(jsStringHandle: E.StringHandle) {
    self.init(handle: jsStringHandle)
  }

  public init(_ string: String) {
    handle = E.makeJSString(string)
    self.string = string
  }

  deinit {
    _ = handle.releaseReference()
  }
}

public struct JSStringValue<E: JSEngine>: @unchecked Sendable, ~Copyable, JSString {
  package let handle: E.StringHandle
  public var jsStringHandle: E.StringHandle { handle }
  public let cached: String?
  public var string: String {
    cached
      ?? String(jsStringHandle: handle, engine: E.self)
  }

  public init(handle: E.StringHandle) {
    _ = handle.retainReference()
    self.handle = handle
    cached = nil
  }

  public init(jsStringHandle: E.StringHandle) {
    self.init(handle: jsStringHandle)
  }

  public init(_ string: String) {
    handle = E.makeJSString(string)
    self.cached = string
  }

  public init(_ string: borrowing JSStringValue<E>, caching: Bool = false) {
    let retainedHandle = string.handle
    _ = retainedHandle.retainReference()
    handle = retainedHandle
    self.cached =
      if caching {
        string.string
      } else {
        string.cached
      }
  }

  public init(_ string: borrowing some JSString, caching: Bool = false) {
    handle = E.makeJSString(string.string)
    self.cached =
      if caching {
        string.string
      } else {
        nil
      }
  }

  deinit {
    _ = handle.releaseReference()
  }
}

extension JSStringValue: TransferableCopy {
  public init(copying string: borrowing JSStringValue<E>) {
    self.init(string, caching: false)
  }
}
