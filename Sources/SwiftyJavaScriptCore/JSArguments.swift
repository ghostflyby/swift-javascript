import JavaScriptCore

extension JSArguments where E == JavaScriptCoreEngine {
  public init(pointer: UnsafePointer<JSValueRef?>, count: Int) {
    self.init(count: count) { index, contextHandle in
      guard index >= 0 && index < count, let valueRef = pointer[index] else {
        return nil
      }
      return JavaScriptCoreEngine.valueHandle(from: valueRef, in: contextHandle)
    }
  }
}
