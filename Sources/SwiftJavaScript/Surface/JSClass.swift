/// An engine class wrapper.
///
/// The concrete type is the engine's class (`JSCClass`, `QJSClass`); class
/// definition/storage/lookup templates stay in core. The protocol requires the
/// raw class handle, which is all shared class code needs for identity:
/// retain/release stay the concrete wrapper's responsibility.
public protocol JSClass: AnyObject {
  /// The context type instances of this class live in.
  associatedtype Context: JSContext
  associatedtype ClassHandle: JSClassManualReferenceCountedHandle
  where ClassHandle == Context.ClassHandle

  func classHandle() -> ClassHandle
}
