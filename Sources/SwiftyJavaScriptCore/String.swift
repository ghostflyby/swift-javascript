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
	var cached: String? { get }
	var string: String { get }
	init(ref: JSStringRef)
	init(_ string: String)
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
	public var cached: String? { string }
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

public struct JSString: @unchecked Sendable, ~Copyable, JSStringProtocol {

	public let ref: JSStringRef
	public let cached: String?
	public var string: String {
		cached
			?? String(jsStringRef: ref)
	}

	public init(ref: JSStringRef) {
		self.ref = JSStringRetain(ref)
		cached = nil
	}

	public init(_ string: String) {
		ref = JSStringCreateWithUTF8CString(string)
		self.cached = string
	}

	public init(_ string: borrowing JSString, caching: Bool = false) {
		ref = JSStringRetain(string.ref)
		self.cached =
			if caching {
				string.string
			} else {
				string.cached
			}
	}

	public init(_ string: borrowing some JSStringProtocol, caching: Bool = false) {
		ref = JSStringRetain(string.ref)
		self.cached =
			if caching {
				string.string
			} else {
				nil
			}
	}
    
	deinit {
		JSStringRelease(ref)
	}
}

extension JSString: TransferableCopy {
	public init(copying string: borrowing JSString) {
		self.init(string, caching: false)
	}
}
