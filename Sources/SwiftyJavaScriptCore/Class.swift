import JavaScriptCore

public typealias JSClassDefinition = JavaScriptCore.JSClassDefinition

@frozen
public struct JSClass: @unchecked Sendable, ~Copyable, TransferableCopy {
	public let ref: JSClassRef

	public init(defination: inout JSClassDefinition) {
		self.ref = JSClassCreate(&defination)
	}

	public init(copying other: borrowing Self) {
		ref = JSClassRetain(other.ref)
	}
	deinit {
		JSClassRelease(ref)
	}
}
