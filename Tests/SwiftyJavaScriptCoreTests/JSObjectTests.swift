import Testing

@testable import SwiftyJavaScriptCore

@Test func propertyAttributesOptionSet() {
  let value: JSPropertyAttributes = [.dontDelete, .readOnly]

  #expect(value.contains(.dontDelete))
  #expect(value.contains(.readOnly))
  #expect(!value.contains(.dontEnum))
  #expect(JSPropertyAttributes.none.rawValue == 0)
}

@Test func setGetHasDeletePropertyWithStringKey() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let key = JSStringManaged("strKey")
    global.setProperty(TestNumberMarshal(3.5), forKey: key, in: context)

    let hasBeforeDelete = global.hasProperty(key, in: context)
    let read = global.getProperty(forKey: key, in: context)
    let readIsNumber = read.isNumber(in: context)

    #expect(hasBeforeDelete)
    #expect(readIsNumber)

    global.deleteProperty(forKey: key, in: context)
    let hasAfterDelete = global.hasProperty(key, in: context)
    #expect(!hasAfterDelete)
  }
}

@Test func setGetHasDeletePropertyWithValueKey() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let key = JSValue(string: "valueKey", in: context)
    global.setProperty(TestStringMarshal("abc"), forKey: key, in: context)

    let hasBeforeDelete = global.hasProperty(key, in: context)
    let read = global.getProperty(forKey: key, in: context)
    let readIsString = read.isString(in: context)

    #expect(hasBeforeDelete)
    #expect(readIsString)

    global.deleteProperty(forKey: key, in: context)
    let hasAfterDelete = global.hasProperty(key, in: context)
    #expect(!hasAfterDelete)
  }
}

@Test func setGetPropertyAtIndex() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(TestBoolMarshal(true), at: 2, in: context)
    let read = global.getProperty(at: 2, in: context)
    let readIsBoolean = read.isBoolean(in: context)
    #expect(readIsBoolean)
  }
}
