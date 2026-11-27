import JavaScriptCore
import SwiftJavaScript

/// A self-owning JavaScriptCore property string key.
///
/// Keeps the `JSStringRef` alive plus a reference to the context that created
/// it, so the key can outlive `JSCContext`/`JSCInstantContext`. The context
/// holds the reverse reference: an input still registered at context teardown
/// is released there, and a live context takes the references back through its
/// actor when the input dies first.
public struct JSCPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let stringBits: UInt
  private let contextBits: UInt
  private let inputToken: UInt64?
  private let contextReference: JSCContextReference?

  package var stringRef: JSStringRef {
    JSStringRef(bitPattern: stringBits)!
  }

  package init(
    stringRef: JSStringRef,
    contextRef: JSGlobalContextRef,
    context: JSCContext?
  ) {
    self.stringBits = UInt(bitPattern: stringRef)
    self.contextBits = UInt(bitPattern: contextRef)
    _ = JSGlobalContextRetain(contextRef)
    if let context {
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

  /// The engine key reference, validated against the context that created it.
  /// Package-internal: the protocol surface no longer names engine handles,
  /// but the compatibility precondition stays on every engine-internal use
  /// (do not replace it with a field read).
  package borrowing func borrowString(
    in contextRef: JSGlobalContextRef
  ) -> JSStringRef {
    precondition(
      JSCEngine.isPropertyStringKeyHandleCompatibleWithContext(stringRef, in: contextRef),
      "JSCPropertyStringKey can only be used with the context that created it"
    )
    return stringRef
  }

  deinit {
    if let contextReference {
      // A live context takes the references back here, on the VM executor; a
      // dead one already released them at teardown.
      guard let context = contextReference.value, let inputToken else { return }
      let token = inputToken
      scheduleOnSerialExecutor(context.virtualMachine.executor) {
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
/// reference and a context reference, exactly like `JSCPropertyStringKey`.
public struct JSCPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let scriptBits: UInt
  private let contextBits: UInt
  private let inputToken: UInt64?
  private let contextReference: JSCContextReference?

  package var scriptRef: JSStringRef {
    JSStringRef(bitPattern: scriptBits)!
  }

  package init(
    scriptRef: JSStringRef,
    contextRef: JSGlobalContextRef,
    context: JSCContext?
  ) {
    self.scriptBits = UInt(bitPattern: scriptRef)
    self.contextBits = UInt(bitPattern: contextRef)
    _ = JSGlobalContextRetain(contextRef)
    if let context {
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

  /// The engine script reference, validated against the context that compiled
  /// it. Package-internal: the protocol surface no longer names engine
  /// handles, but the compatibility precondition stays on every
  /// engine-internal use (do not replace it with a field read).
  package borrowing func borrowScript(
    in contextRef: JSGlobalContextRef
  ) -> JSStringRef {
    precondition(
      JSCEngine.isPreparedScriptHandleCompatibleWithContext(scriptRef, in: contextRef),
      "JSCPreparedScript can only be used with the context that compiled it"
    )
    return scriptRef
  }

  deinit {
    if let contextReference {
      // A live context takes the references back here, on the VM executor; a
      // dead one already released them at teardown.
      guard let context = contextReference.value, let inputToken else { return }
      let token = inputToken
      scheduleOnSerialExecutor(context.virtualMachine.executor) {
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
