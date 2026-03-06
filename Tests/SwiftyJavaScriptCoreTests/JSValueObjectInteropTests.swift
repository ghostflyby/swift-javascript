import Testing

@testable import SwiftyJavaScriptCore

@Test func jsValueObjectAndTypeHelpersWork() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

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
            let isObject = object.isObject
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
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let object = JSValue(objectIn: context)
    let key = JSStringManaged("locked")

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
