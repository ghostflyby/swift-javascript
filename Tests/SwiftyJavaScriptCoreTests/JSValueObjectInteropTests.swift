import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreValueHandleStorageRoundTripsPointerWords() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withInstantContext { context in
    let value = JSValue(number: 42, in: context)
    let handle = value.borrowHandle()
    var storage = SwiftJavaScript.JSValueStorage()

    handle.bindToStorage(&storage)

    let restored = JavaScriptCoreValueHandle(storage: storage)
    #expect(restored.ref == handle.ref)
    #expect(restored.contextRef == handle.contextRef)

    var reboundStorage = SwiftJavaScript.JSValueStorage()
    restored.bindToStorage(&reboundStorage)
    #expect(reboundStorage.word0 == storage.word0)
    #expect(reboundStorage.word1 == storage.word1)
    #expect(reboundStorage.word2 == storage.word2)
  }
}

@Test func jsValueObjectAndTypeHelpersWork() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let arrayResult = context.evaluateScript("[1, 2, 3]")
    let dateResult = context.evaluateScript("new Date(0)")
    let arrayConstructorResult = context.evaluateScript("Array")

    switch consume arrayResult {
    case .value(let array):
      switch consume dateResult {
      case .value(let date):
        switch consume arrayConstructorResult {
        case .value(let arrayConstructor):
          let arrayIsArray = array.isArray(in: context)
          let arrayIsDate = array.isDate(in: context)
          let dateIsDate = date.isDate(in: context)
          let isArrayInstance = array.isInstanceOf(arrayConstructor, in: context)
          #expect(arrayIsArray)
          #expect(!arrayIsDate)
          #expect(dateIsDate)
          #expect(isArrayInstance)

          let primitive = JSValue(number: 42, in: context)
          let objectResult = primitive.toObject(in: context)
          switch consume objectResult {
          case .value(let object):
            let isObject = object.isObject(in: context)
            #expect(isObject)
          case .exception:
            Issue.record("Expected toObject to box primitive numbers")
          }

          #expect(primitive.toNumber(in: context) == 42)
        case .exception:
          Issue.record("Expected Array constructor value")
        }
      case .exception:
        Issue.record("Expected Date instance value")
      }
    case .exception:
      Issue.record("Expected array value")
    }
  }
}

@Test func jsValueDefinePropertyAppliesAttributes() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let object = JSValue(objectIn: context)
    let key = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("locked")

    let defineResult = object.defineProperty(7, forKey: key, with: [.readOnly], in: context)
    switch consume defineResult {
    case .value(let stored):
      #expect(stored.toInt32(in: context) == 7)
    case .exception:
      Issue.record("Expected defineProperty to succeed")
    }

    object.setProperty(9, forKey: key, in: context)
    let stored = object.getProperty(forKey: key, in: context)
    #expect(stored.toInt32(in: context) == 7)
  }
}

@Test func jsValueDefinePropertyRespectsDontEnumAndDontDelete() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let hiddenKey = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("hiddenFlag")
    let pinnedKey = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("pinnedFlag")

    _ = global.defineProperty(true, forKey: hiddenKey, with: [.dontEnum], in: context)
    _ = global.defineProperty(1, forKey: pinnedKey, with: [.dontDelete], in: context)

    let hiddenEnumerated = context.evaluateScript(
      "Object.keys(globalThis).includes('hiddenFlag')"
    )
    let pinnedDeleted = context.evaluateScript(
      "delete globalThis.pinnedFlag"
    )
    let pinnedStillPresent = context.evaluateScript(
      "'pinnedFlag' in globalThis"
    )

    switch consume hiddenEnumerated {
    case .value(let value):
      let isEnumerated = value.toBool(in: context)
      #expect(!isEnumerated)
    case .exception:
      Issue.record("Expected Object.keys check for hiddenFlag")
    }

    switch consume pinnedDeleted {
    case .value(let value):
      let didDelete = value.toBool(in: context)
      #expect(!didDelete)
    case .exception:
      Issue.record("Expected delete operator check for pinnedFlag")
    }

    switch consume pinnedStillPresent {
    case .value(let value):
      let stillPresent = value.toBool(in: context)
      #expect(stillPresent)
    case .exception:
      Issue.record("Expected membership check for pinnedFlag")
    }
  }
}

@Test func jsValueObjectAndArrayInitializersCreateExpectedKinds() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let object = JSValue(objectIn: context)
    let array = JSValue(arrayIn: context)
    let objectIsObject = object.isObject(in: context)
    let arrayIsObject = array.isObject(in: context)
    let arrayIsArray = array.isArray(in: context)

    #expect(objectIsObject)
    #expect(arrayIsObject)
    #expect(arrayIsArray)
  }
}
