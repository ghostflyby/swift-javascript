struct _JSValueRawStorage: ~Copyable {
	let ref: JavaScriptCoreValueRef

	init(ref: JavaScriptCoreValueRef) {
		self.ref = ref
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
	func rawValue(
		from rawStorage: borrowing _JSValueRawStorage,
		in context: JavaScriptCoreRawContext
	) -> JavaScriptCoreRawValue
}

private struct _JSCJSValueStorageBridge: _JSValueStorageBridge {
	typealias Handle = JSValueHandle<JavaScriptCoreEngine>

	func rawStorage(from ref: JavaScriptCoreValueRef) -> _JSValueRawStorage {
		_JSValueRawStorage(ref: ref)
	}

	func rawStorage(from rawValue: JavaScriptCoreRawValue) -> _JSValueRawStorage {
    _JSValueRawStorage(ref: rawValue.ref)
	}

	func rawStorage(from handle: Handle) -> _JSValueRawStorage? {
		guard let ref = JavaScriptCoreBackendDriver.valueRef(from: handle) else {
			return nil
		}
		return _JSValueRawStorage(ref: ref)
	}

	func handle(
		from rawStorage: borrowing _JSValueRawStorage,
		in context: borrowing JSInstantContext
	) -> Handle {
		guard
			let handle = JavaScriptCoreBackendDriver.valueHandle(
				from: rawStorage.ref,
				in: context.driverContextHandle
			)
		else {
			preconditionFailure("JSValue storage could not create value handle")
		}
		return handle
	}

	func rawValue(
		from rawStorage: borrowing _JSValueRawStorage,
		in context: JavaScriptCoreRawContext
	) -> JavaScriptCoreRawValue {
		JavaScriptCoreBackendDriver.rawValue(from: rawStorage.ref, in: context)
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
		_jsValueStorageBridge.rawValue(from: rawStorage, in: context)
	}

	func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
		_jsValueStorageBridge.handle(from: rawStorage, in: context)
	}
}