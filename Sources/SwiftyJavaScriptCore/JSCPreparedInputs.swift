import JavaScriptCore
import SwiftJavaScript

/// A self-owning JavaScriptCore property string key.
///
/// Keeps the `JSStringRef` alive plus a reference to the context that created
/// it, so the key can outlive `JSCContext`/`JSCInstantContext`. The context
/// holds the reverse reference: an input still registered at context teardown
/// is released there, and a live context takes the references back through its
/// actor when the input dies first. A key that outlives its actor is therefore
/// no longer valid for use.
///
/// A `JSStringRef` is context-free, so the key carries no context-affinity
/// guard; `stringRef` is read directly. The `init(_:)` form creates the key
/// without any context and owns just the string.
public struct JSCPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let stringBits: UInt
  private let contextBits: UInt
  private let inputToken: UInt64?
  private let contextReference: JSCContextReference?

  package var stringRef: JSStringRef {
    JSStringRef(bitPattern: stringBits)!
  }

  /// Create a key without a context. `JSStringRef` is context-free, so the
  /// key owns only the string and can be used with any context.
  public init(_ value: String) {
    let stringRef = JSStringCreateWithCFString(value as CFString)!
    self.init(stringRef: stringRef, contextRef: nil, context: nil)
  }

  package init(
    stringRef: JSStringRef,
    contextRef: JSGlobalContextRef?,
    context: JSCContext?
  ) {
    self.stringBits = UInt(bitPattern: stringRef)
    self.contextBits = contextRef.map(UInt.init(bitPattern:)) ?? 0
    if let contextRef {
      _ = JSGlobalContextRetain(contextRef)
    }
    if let context, let contextRef {
      self.contextReference = JSCContextReference(context)
      self.inputToken = context.registerInput(
        stringBits: UInt(bitPattern: stringRef),
        contextBits: UInt(bitPattern: contextRef)
      )
    } else {
      self.contextReference = nil
      self.inputToken = nil
    }
  }

  deinit {
    if let contextReference {
      // A live context takes the references back here, on the VM executor; a
      // dead one already released them at teardown.
      guard let context = contextReference.value, let inputToken else { return }
      let token = inputToken
      scheduleOnTaskExecutor(context.virtualMachine.executor) {
        context.releaseInput(token)
      }
      return
    }
    // Created without a context (a raw engine window): the creator owns the
    // release, on the calling thread.
    if let stringRef = JSStringRef(bitPattern: stringBits) {
      JSStringRelease(stringRef)
    }
    if let contextRef = JSGlobalContextRef(bitPattern: contextBits) {
      JSGlobalContextRelease(contextRef)
    }
  }
}

/// A self-owning JavaScriptCore prepared script.
///
/// JavaScriptCore caches the script as a `JSStringRef`; the wrapper owns that
/// reference plus, when it was created through a context, the context
/// reference used for settlement. The `init(source:)` form creates the script
/// without a context and owns just the string.
public struct JSCPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let scriptBits: UInt
  private let contextBits: UInt
  private let inputToken: UInt64?
  private let contextReference: JSCContextReference?

  package var scriptRef: JSStringRef {
    JSStringRef(bitPattern: scriptBits)!
  }

  /// Create a script without a context. JavaScriptCore caches source text in
  /// a context-free `JSStringRef`, so the script can be evaluated by any
  /// context.
  public init(source: String) {
    let scriptRef = JSStringCreateWithCFString(source as CFString)!
    self.init(scriptRef: scriptRef, contextRef: nil, context: nil)
  }

  package init(
    scriptRef: JSStringRef,
    contextRef: JSGlobalContextRef?,
    context: JSCContext?
  ) {
    self.scriptBits = UInt(bitPattern: scriptRef)
    self.contextBits = contextRef.map(UInt.init(bitPattern:)) ?? 0
    if let contextRef {
      _ = JSGlobalContextRetain(contextRef)
    }
    if let context, let contextRef {
      self.contextReference = JSCContextReference(context)
      self.inputToken = context.registerInput(
        stringBits: UInt(bitPattern: scriptRef),
        contextBits: UInt(bitPattern: contextRef)
      )
    } else {
      self.contextReference = nil
      self.inputToken = nil
    }
  }

  deinit {
    if let contextReference {
      // A live context takes the references back here, on the VM executor; a
      // dead one already released them at teardown.
      guard let context = contextReference.value, let inputToken else { return }
      let token = inputToken
      scheduleOnTaskExecutor(context.virtualMachine.executor) {
        context.releaseInput(token)
      }
      return
    }
    // Created without a context (a raw engine window): the creator owns the
    // release, on the calling thread.
    if let scriptRef = JSStringRef(bitPattern: scriptBits) {
      JSStringRelease(scriptRef)
    }
    if let contextRef = JSGlobalContextRef(bitPattern: contextBits) {
      JSGlobalContextRelease(contextRef)
    }
  }
}
