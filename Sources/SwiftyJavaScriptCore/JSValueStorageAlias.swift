struct _JSValueRawStorage: ~Copyable {
	let ref: JavaScriptCoreValueRef

	init(ref: JavaScriptCoreValueRef) {
		self.ref = ref
	}

	init(rawValue: JavaScriptCoreRawValue) {
		self.ref = rawValue.ref
	}

	static func fromHandle(
		_ handle: JSValueHandle<JavaScriptCoreEngine>
	) -> _JSValueRawStorage? {
		guard let rawValue: JavaScriptCoreRawValue = handle.opaqueHandle() else {
			return nil
		}
		return _JSValueRawStorage(rawValue: rawValue)
	}

	func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
		JavaScriptCoreRawValue(ref: ref, context: context)
	}

	func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
		JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: rawValue(in: context.driverContext))
	}
}

private protocol _JSValueStorageBridge {
	associatedtype Handle

	func rawStorage(from ref: JavaScriptCoreValueRef) -> _JSValueRawStorage
	func rawStorage(from rawValue: JavaScriptCoreRawValue) -> _JSValueRawStorage
	func rawStorage(from handle: Handle) -> _JSValueRawStorage?
	func handle(
		from rawStorage: borrowing _JSValueRawStorage,
		in context: borrowing JSInstantContext
	) -> Handle
}

private struct _JSCJSValueStorageBridge: _JSValueStorageBridge {
	typealias Handle = JSValueHandle<JavaScriptCoreEngine>

	func rawStorage(from ref: JavaScriptCoreValueRef) -> _JSValueRawStorage {
		_JSValueRawStorage(ref: ref)
	}

	func rawStorage(from rawValue: JavaScriptCoreRawValue) -> _JSValueRawStorage {
		_JSValueRawStorage(rawValue: rawValue)
	}

	func rawStorage(from handle: Handle) -> _JSValueRawStorage? {
		_JSValueRawStorage.fromHandle(handle)
	}

	func handle(
		from rawStorage: borrowing _JSValueRawStorage,
		in context: borrowing JSInstantContext
	) -> Handle {
		rawStorage.valueHandle(in: context)
	}
}

private let _jsValueStorageBridge = _JSCJSValueStorageBridge()

struct _JSValueStorage: ~Copyable {
	private let rawStorage: _JSValueRawStorage

	init(ref: JavaScriptCoreValueRef) {
		self.rawStorage = _jsValueStorageBridge.rawStorage(from: ref)
	}

	init(rawValue: JavaScriptCoreRawValue) {
		self.rawStorage = _jsValueStorageBridge.rawStorage(from: rawValue)
	}

	static func fromHandle(
		_ handle: JSValueHandle<JavaScriptCoreEngine>
	) -> _JSValueStorage? {
		guard let rawStorage = _jsValueStorageBridge.rawStorage(from: handle) else {
			return nil
		}
		return _JSValueStorage(ref: rawStorage.ref)
	}

	var ref: JavaScriptCoreValueRef {
		rawStorage.ref
	}

	func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
		rawStorage.rawValue(in: context)
	}

	func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
		_jsValueStorageBridge.handle(from: rawStorage, in: context)
	}
}