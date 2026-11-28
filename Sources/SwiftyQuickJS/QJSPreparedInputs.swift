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
/// that created it alive, so the key can outlive `QJSContext`. The context
/// holds the reverse reference: an input still registered at context teardown
/// is released there, and a live context takes the references back through its
/// actor when the input dies first.
public struct QJSPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = QJSContext

  package let atom: JSAtom
  private let contextBits: UInt
  private let inputToken: UInt64?
  private let contextReference: QJSContextReference?

  package init(
    atom: JSAtom,
    contextRef: OpaquePointer,
    context: QJSContext?
  ) {
    self.atom = atom
    self.contextBits = UInt(bitPattern: contextRef)
    _ = JS_DupContext(contextRef)
    if let context {
      self.contextReference = QJSContextReference(context)
      self.inputToken = context.registerInput(
        atom: atom,
        contextBits: UInt(bitPattern: contextRef)
      )
    } else {
      self.contextReference = nil
      self.inputToken = nil
    }
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
    guard let context = OpaquePointer(bitPattern: contextBits) else { return }
    JS_FreeAtom(context, atom)
    JS_FreeContext(context)
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
  private let inputToken: UInt64?
  private let contextReference: QJSContextReference?

  package init(
    source: String,
    contextRef: OpaquePointer,
    context: QJSContext?
  ) {
    self.source = source
    self.contextBits = UInt(bitPattern: contextRef)
    _ = JS_DupContext(contextRef)
    if let context {
      self.contextReference = QJSContextReference(context)
      self.inputToken = context.registerInput(
        atom: nil,
        contextBits: UInt(bitPattern: contextRef)
      )
    } else {
      self.contextReference = nil
      self.inputToken = nil
    }
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
    guard let context = OpaquePointer(bitPattern: contextBits) else { return }
    JS_FreeContext(context)
  }
}
