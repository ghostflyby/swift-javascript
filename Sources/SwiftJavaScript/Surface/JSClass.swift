/// An engine class wrapper.
///
/// The concrete type is the engine's class (`JSCClass`, `QJSClass`); class
/// definition/storage/lookup templates stay in core. The protocol only names
/// the context the class lives in: class creation, host objects and their
/// private data are engine statics (`JSEngineClassBridgeDriver`), so no handle
/// type appears on the public class surface.
public protocol JSClass: AnyObject {
  /// The context type instances of this class live in.
  associatedtype Context: JSContext
}
