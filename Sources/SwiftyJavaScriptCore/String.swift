import JavaScriptCore

extension String {
	public init(jsStringRef: JSStringRef) {
		let length = JSStringGetLength(jsStringRef)
		let characters = JSStringGetCharactersPtr(jsStringRef)!
		self = String(utf16CodeUnits: characters, count: length)
	}
}

public protocol JSStringProtocol: ~Copyable {
	var ref: JSStringRef { get }
	var string: String { get }
	init(ref: JSStringRef)
}

extension JSStringProtocol {
	public init(group: borrowing some JSStringProtocol) {
		self.init(ref: group.ref)
	}
}

extension JSStringProtocol {
	public static func == (lhs: borrowing Self, rhs: borrowing some JSStringProtocol) -> Bool {
		JSStringIsEqual(lhs.ref, rhs.ref)
	}

	public static func != (lhs: borrowing Self, rhs: borrowing some JSStringProtocol) -> Bool {
		!(lhs == rhs)
	}

}

public final class JSStringClass: @unchecked Sendable, JSStringProtocol {

	public let ref: JSStringRef
	public let string: String

	public init(ref: JSStringRef) {
		self.ref = JSStringRetain(ref)
		string = String(jsStringRef: ref)
	}

	public init(_ string: String) {
		ref = JSStringCreateWithUTF8CString(string)
		self.string = string
	}

	deinit {
		JSStringRelease(ref)
	}
}

public struct JSString: @unchecked Sendable, ~Copyable, TransferableCopy {

	public let ref: JSStringRef
	private let cached: String?
	public var string: String {
		cached
			?? String(jsStringRef: ref)
	}

	public init(_ string: String) {
		ref = JSStringCreateWithUTF8CString(string)
		self.cached = string
	}

	public init(copying string: borrowing JSString) {
		self.init(string, caching: false)
	}

	public init(_ string: borrowing JSString, caching: Bool = false) {
		ref = string.ref
		self.cached =
			if caching {
				string.string
			} else {
				string.cached
			}
		JSStringRetain(ref)
	}

	deinit {
		JSStringRelease(ref)
	}
}
