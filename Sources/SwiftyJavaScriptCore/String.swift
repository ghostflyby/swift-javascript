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
	init(ref: JSStringRef)
}

public struct JSString: @unchecked Sendable, ~Copyable, TransferableCopy {

	public let ref: JSStringRef
	public let cached: String?
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

	public static func == (lhs: borrowing JSString, rhs: borrowing JSString) -> Bool {
		JSStringIsEqual(lhs.ref, rhs.ref)
	}

	deinit {
		JSStringRelease(ref)
	}
}
