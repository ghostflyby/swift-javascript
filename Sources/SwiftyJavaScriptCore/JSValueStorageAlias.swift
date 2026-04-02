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

struct _JSValueStorage: ~Copyable {
	private let rawStorage: _JSValueRawStorage

	init(ref: JavaScriptCoreValueRef) {
		self.rawStorage = _JSValueRawStorage(ref: ref)
	}

	init(rawValue: JavaScriptCoreRawValue) {
		self.rawStorage = _JSValueRawStorage(rawValue: rawValue)
	}

	static func fromHandle(
		_ handle: JSValueHandle<JavaScriptCoreEngine>
	) -> _JSValueStorage? {
		guard let rawStorage = _JSValueRawStorage.fromHandle(handle) else {
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
		rawStorage.valueHandle(in: context)
	}
}