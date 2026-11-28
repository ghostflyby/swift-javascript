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
/// Owns one atom reference (`JS_NewAtom` / `JS_FreeAtom`) and retains the raw
/// engine context, so the C context stays valid for the key's lifetime. The
/// context actor holds the reverse settlement: a key that outlives the actor
/// has its atom released at teardown, so a key is valid for use only while
/// the context that minted it is alive.
///
/// The atom is runtime-scoped, not context-scoped: while the minting context
/// is alive the key can be used from any context of the same runtime. Use
/// checks runtime affinity, never context identity.
public struct QJSPropertyStringKey: SwiftJavaScript.JSPropertyStringKey, Sendable, ~Copyable {
  public typealias Context = QJSContext

  package let atom: JSAtom
  private let runtimeBits: UInt
  private let contextBits: UInt
  private let inputToken: UInt64?
  private let contextReference: QJSContextReference?

  package init(
    atom: JSAtom,
    contextRef: OpaquePointer,
    context: QJSContext?
  ) {
    self.atom = atom
    self.runtimeBits = UInt(bitPattern: JS_GetRuntime(contextRef))
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

  /// The engine atom, validated against the runtime that owns it.
  ///
  /// A `JSAtom` is an index into the runtime's atom table, so the only
  /// compatibility that matters is runtime identity. Any context of that
  /// runtime is a valid operation context. The source context must still be
  /// alive: it owns the atom settlement, and a key that outlived its actor no
  /// longer holds a valid atom.
  package borrowing func borrowAtom(in contextRef: OpaquePointer) -> JSAtom {
    precondition(
      contextReference == nil || contextReference?.value != nil,
      "QJSPropertyStringKey can only be used while the context that created it is alive"
    )
    precondition(
      JS_GetRuntime(contextRef) == OpaquePointer(bitPattern: runtimeBits),
      "QJSPropertyStringKey can only be used with contexts of the runtime that created it"
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

/// A QuickJS prepared script.
///
/// QuickJS re-evaluates the cached source, so the wrapper is nothing but the
/// source string: it holds no engine reference and needs no context. It can be
/// created directly and evaluated by any context.
public struct QJSPreparedScript: SwiftJavaScript.JSPreparedScript, Sendable, ~Copyable {
  public typealias Context = QJSContext

  package let source: String

  /// Create a script without a context. QuickJS re-evaluates the source text,
  /// so the script has no engine representation to bind.
  public init(source: String) {
    self.source = source
  }
}
