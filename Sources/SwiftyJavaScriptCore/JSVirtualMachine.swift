import JavaScriptCore.JSVirtualMachine

public class JSVirtualMachine: @unchecked Sendable {
  let peer: JavaScriptCore.JSVirtualMachine
  let unownedExecutor: UnownedSerialExecutor

  public init() {
    self.peer = .init()
    unownedExecutor = SingleThreadExecutor().asUnownedSerialExecutor()
  }

}

extension JSVirtualMachine: Hashable {
  public static func == (lhs: JSVirtualMachine, rhs: JSVirtualMachine) -> Bool {
    return lhs.peer === rhs.peer
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(peer))
  }
}

@available(macOS 14.0, *)
// FIXME: actually implement a single-threaded executor
private class SingleThreadExecutor: SerialExecutor, @unchecked Sendable {

  func enqueue(_ job: consuming ExecutorJob) {
  }
}
