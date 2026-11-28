import JavaScriptCore
import SwiftJavaScript

/// A self-owning JavaScriptCore property string key.
///
/// A `JSStringRef` is context-free and reference-counted independently of any
/// context, so the key owns just the string. It can be created and used
/// without a context, can outlive the context that minted it, and is valid in
/// any context group.
public struct JSCPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let stringBits: UInt

  package var stringRef: JSStringRef {
    JSStringRef(bitPattern: stringBits)!
  }

  /// Create a key without a context. `JSStringRef` is context-free, so the
  /// key owns only the string and can be used with any context.
  public init(_ value: String) {
    self.init(stringRef: JSStringCreateWithCFString(value as CFString)!)
  }

  package init(stringRef: JSStringRef) {
    self.stringBits = UInt(bitPattern: stringRef)
  }

  deinit {
    if let stringRef = JSStringRef(bitPattern: stringBits) {
      JSStringRelease(stringRef)
    }
  }
}

/// A self-owning JavaScriptCore prepared script.
///
/// JavaScriptCore caches the script as a context-free `JSStringRef`; the
/// wrapper owns that reference and nothing else. It can be created without a
/// context, can outlive the context that minted it, and is valid in any
/// context group.
public struct JSCPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let scriptBits: UInt

  package var scriptRef: JSStringRef {
    JSStringRef(bitPattern: scriptBits)!
  }

  /// Create a script without a context. JavaScriptCore caches source text in
  /// a context-free `JSStringRef`, so the script can be evaluated by any
  /// context.
  public init(source: String) {
    self.init(scriptRef: JSStringCreateWithCFString(source as CFString)!)
  }

  package init(scriptRef: JSStringRef) {
    self.scriptBits = UInt(bitPattern: scriptRef)
  }

  deinit {
    if let scriptRef = JSStringRef(bitPattern: scriptBits) {
      JSStringRelease(scriptRef)
    }
  }
}
