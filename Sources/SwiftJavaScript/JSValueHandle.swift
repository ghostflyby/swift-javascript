public typealias JSValueHandle<E: JSEngineValueTypes> = E.ValueHandle

/// The `~Copyable` ownership-carrier counterpart of `JSValueHandle`:
/// creation results, scope-arena elements, and ownership handoffs.
public typealias JSOwnedValueHandle<E: JSEngineValueTypes> = E.OwnedValueHandle
