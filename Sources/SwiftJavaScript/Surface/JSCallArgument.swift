/// A value-level token for one function-call argument.
///
/// A value view is `~Copyable`, so an array cannot carry value views directly.
/// Each engine declares one `Copyable` conforming structure that stores only a
/// borrowed engine handle, and `JSValue.asCallArgument()` produces it from a
/// value. This protocol
/// deliberately declares no members: generic code never inspects a token, it
/// only forwards tokens back to the engine that produced them.
///
/// Lifetime: a token borrows the handle of the value it was made from. It is
/// valid only while that value's arena is alive and only for the immediate,
/// synchronous call it is passed to. Tokens are public types, but must not be
/// stored across windows or across `await` — on QuickJS the borrowed handle
/// dangles once the source window drains.
public protocol JSCallArgument {}
