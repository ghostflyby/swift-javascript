public enum JSHostObjectStoragePolicy: Sendable, Hashable {
  case unmanagedOpaquePointer
  case swiftRetainedObject
  case valueSemanticCopy
}
