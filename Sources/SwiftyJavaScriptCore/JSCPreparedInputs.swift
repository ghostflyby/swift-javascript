import JavaScriptCore
import SwiftJavaScript

/// A self-owning JavaScriptCore property string key.
///
/// Keeps the `JSStringRef` alive plus a reference to the context that created
/// it, so the key can outlive `JSCContext`/`JSCInstantContext`. The release is
/// routed to the context's VM thread when it has one; the shared algorithm is
/// `releasePreparedInput` in core.
public struct JSCPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = JSCContext

  private let stringBits: UInt
  private let contextBits: UInt
  private let vmThread: VMThread?

  package var stringRef: JSStringRef {
    JSStringRef(bitPattern: stringBits)!
  }

  package init(
    stringRef: JSStringRef,
    contextRef: JSGlobalContextRef,
    vmThread: VMThread?
  ) {
    self.stringBits = UInt(bitPattern: stringRef)
    self.contextBits = UInt(bitPattern: contextRef)
    self.vmThread = vmThread
    _ = JSGlobalContextRetain(contextRef)
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
    let stringBits = self.stringBits
    let contextBits = self.contextBits
    let release: @Sendable () -> Void = {
      if let stringRef = JSStringRef(bitPattern: stringBits) {
        JSStringRelease(stringRef)
      }
      if let contextRef = JSGlobalContextRef(bitPattern: contextBits) {
        JSGlobalContextRelease(contextRef)
      }
    }
    if let vmThread {
      vmThread.perform(release)
    } else {
      release()
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
  private let vmThread: VMThread?

  package var scriptRef: JSStringRef {
    JSStringRef(bitPattern: scriptBits)!
  }

  package init(
    scriptRef: JSStringRef,
    contextRef: JSGlobalContextRef,
    vmThread: VMThread?
  ) {
    self.scriptBits = UInt(bitPattern: scriptRef)
    self.contextBits = UInt(bitPattern: contextRef)
    self.vmThread = vmThread
    _ = JSGlobalContextRetain(contextRef)
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
    let scriptBits = self.scriptBits
    let contextBits = self.contextBits
    let release: @Sendable () -> Void = {
      if let scriptRef = JSStringRef(bitPattern: scriptBits) {
        JSStringRelease(scriptRef)
      }
      if let contextRef = JSGlobalContextRef(bitPattern: contextBits) {
        JSGlobalContextRelease(contextRef)
      }
    }
    if let vmThread {
      vmThread.perform(release)
    } else {
      release()
    }
  }
}
