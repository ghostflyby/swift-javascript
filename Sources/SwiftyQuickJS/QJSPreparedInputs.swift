import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// A self-owning QuickJS property string key.
///
/// Owns one atom reference (`JS_NewAtom` / `JS_FreeAtom`) and keeps the context
/// that created it alive, so the key can outlive `QJSContext`. Release runs on
/// the context's VM thread when it has one.
public struct QJSPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = QJSContext

  package let atom: JSAtom
  private let contextBits: UInt
  private let vmThread: VMThread?

  package init(
    atom: JSAtom,
    contextRef: OpaquePointer,
    vmThread: VMThread?
  ) {
    self.atom = atom
    self.contextBits = UInt(bitPattern: contextRef)
    self.vmThread = vmThread
    _ = JS_DupContext(contextRef)
  }

  /// The engine atom, validated against the context that created it.
  /// Package-internal: the protocol surface no longer names engine
  /// references, but the compatibility precondition stays on every
  /// engine-internal use.
  package borrowing func borrowAtom(in contextRef: OpaquePointer) -> JSAtom {
    precondition(
      contextBits == UInt(bitPattern: contextRef),
      "QJSPropertyStringKey can only be used with the context that created it"
    )
    return atom
  }

  deinit {
    let atom = self.atom
    let contextBits = self.contextBits
    let release: @Sendable () -> Void = {
      guard let contextRef = OpaquePointer(bitPattern: contextBits) else { return }
      quickJSUpdateStackTop(contextRef)
      JS_FreeAtom(contextRef, atom)
      JS_FreeContext(contextRef)
    }
    if let vmThread {
      vmThread.perform(release)
    } else {
      release()
    }
  }
}

/// A self-owning QuickJS prepared script.
///
/// QuickJS re-evaluates the cached source, so the wrapper carries the source
/// string plus a context reference for lifetime symmetry with
/// `QJSPropertyStringKey`.
public struct QJSPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = QJSContext

  package let source: String
  private let contextBits: UInt
  private let vmThread: VMThread?

  package init(
    source: String,
    contextRef: OpaquePointer,
    vmThread: VMThread?
  ) {
    self.source = source
    self.contextBits = UInt(bitPattern: contextRef)
    self.vmThread = vmThread
    _ = JS_DupContext(contextRef)
  }

  /// The script source, validated against the context that compiled it.
  /// Package-internal: the protocol surface no longer names engine
  /// references, but the compatibility precondition stays on every
  /// engine-internal use.
  package borrowing func borrowSource(in contextRef: OpaquePointer) -> String {
    precondition(
      contextBits == UInt(bitPattern: contextRef),
      "QJSPreparedScript can only be used with the context that compiled it"
    )
    return source
  }

  deinit {
    let contextBits = self.contextBits
    let release: @Sendable () -> Void = {
      guard let contextRef = OpaquePointer(bitPattern: contextBits) else { return }
      quickJSUpdateStackTop(contextRef)
      JS_FreeContext(contextRef)
    }
    if let vmThread {
      vmThread.perform(release)
    } else {
      release()
    }
  }
}
