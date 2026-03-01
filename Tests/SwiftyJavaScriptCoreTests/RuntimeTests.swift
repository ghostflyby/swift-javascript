import Testing

@testable import SwiftyJavaScriptCore

@Test func virtualMachineHashableAndIdentity() {
  let vm1 = SwiftyJavaScriptCore.JSVirtualMachine()
  let vm2 = SwiftyJavaScriptCore.JSVirtualMachine()

  #expect(vm1 == vm1)
  #expect(vm1 != vm2)
  #expect(vm1.hashValue == vm1.hashValue)
}

@Test func contextHashableAndGlobalObject() async {
  let vm = SwiftyJavaScriptCore.JSVirtualMachine()
  let context1 = JSContext(virtualMachine: vm)
  let context2 = JSContext(virtualMachine: vm)

  #expect(context1 == context1)
  #expect(context1 != context2)

  await context1.withIsolatedGlobalObject { _, global in
    let isObject = global.isObject
    let type = global.type
    #expect(isObject)
    #expect(type == .object)
  }
}

@Test func valueInitializersAndTypePredicates() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let undefined = JSValue(undefinedIn: context)
    let null = JSValue(nullIn: context)
    let bool = JSValue(boolean: true, in: context)
    let number = JSValue(number: 42, in: context)
    let string = JSValue(string: "abc", in: context)
    let symbol = JSValue(symbol: "s", in: context)
    let intNumber = JSValue(number: 7 as Int, in: context)

    let undefinedIsUndefined = undefined.isUndefined
    let undefinedType = undefined.type
    #expect(undefinedIsUndefined)
    #expect(undefinedType == .undefined)

    let nullIsNull = null.isNull
    let nullType = null.type
    #expect(nullIsNull)
    #expect(nullType == .null)

    let boolIsBoolean = bool.isBoolean
    let boolType = bool.type
    #expect(boolIsBoolean)
    #expect(boolType == .boolean)

    let numberIsNumber = number.isNumber
    let numberType = number.type
    #expect(numberIsNumber)
    #expect(numberType == .number)

    let stringIsString = string.isString
    let stringType = string.type
    #expect(stringIsString)
    #expect(stringType == .string)

    let symbolIsSymbol = symbol.isSymbol
    let symbolType = symbol.type
    #expect(symbolIsSymbol)
    #expect(symbolType == .symbol)

    let intIsNumber = intNumber.isNumber
    let intIsBigInt = intNumber.isBigInt
    #expect(intIsNumber)
    #expect(!intIsBigInt)
  }
}

@Test func valueEqualityOperators() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, _ in
    let oneNumber = JSValue(number: 1, in: context)
    let oneString = JSValue(string: "1", in: context)
    let oneNumberCopy = JSValue(number: 1, in: context)

    let looselyEqual = oneNumber == oneString
    let looselyNotEqual = oneNumber != JSValue(number: 2, in: context)
    let strictlyEqual = oneNumber === oneNumberCopy
    let strictlyNotEqual = oneNumber !== JSValue(number: 2, in: context)

    #expect(looselyEqual)
    #expect(looselyNotEqual)
    #expect(strictlyEqual)
    #expect(strictlyNotEqual)
  }
}
