/// A self-owning prepared script.
///
/// The concrete type keeps the engine context alive so the script can outlive
/// the `JSContext` actor. The public requirement is only borrowing against a
/// `ContextHandle`; the witness-based overload stays package-internal because
/// `JSScopeWitness` is a package protocol.
public protocol JSPreparedScript: Sendable, ~Copyable {
  /// The context this script belongs to.
  associatedtype Context: JSContext
  /// The context identity the script is validated against.
  associatedtype ContextHandle: JSContextRuntimeDriver
  where ContextHandle == Context.ContextHandle
  associatedtype Handle: Sendable
  where Handle == ContextHandle.PreparedScriptHandle

  /// The engine script handle, validated against the context that compiled it.
  borrowing func borrowHandle(in contextHandle: ContextHandle) -> Handle
}

extension JSPreparedScript where Self: ~Copyable {
  /// Witness-addressed borrowing for the shared scope algorithms. The
  /// compatibility precondition lives in the concrete `ContextHandle`
  /// overload above; this one only supplies the context identity.
  package borrowing func borrowHandle<W: JSScopeWitness & ~Copyable>(
    in witness: borrowing W
  ) -> Handle where W.ContextHandle == ContextHandle {
    borrowHandle(in: witness.driverContextHandle)
  }
}
