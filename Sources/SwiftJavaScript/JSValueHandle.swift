public typealias JSValueHandle<E: JSEngine> = E.ValueHandle

/// The `~Copyable` ownership-carrier counterpart of `JSValueHandle`:
/// creation results, scope-arena elements, and ownership handoffs.
public typealias JSOwnedValueHandle<E: JSEngine> = E.OwnedValueHandle
