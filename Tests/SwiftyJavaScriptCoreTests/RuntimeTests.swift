import Testing

@testable import SwiftyJavaScriptCore

@Test func virtualMachineHashableAndIdentity() {
  let vm1 = JSVirtualMachine<JavaScriptCoreEngine>()
  let vm2 = JSVirtualMachine<JavaScriptCoreEngine>()

  #expect(vm1 == vm1)
  #expect(vm1 != vm2)
  #expect(vm1.hashValue == vm1.hashValue)
}

@Test func contextHashableAndGlobalObject() async {
  let vm = JSVirtualMachine<JavaScriptCoreEngine>()
  let context1 = JSContext(virtualMachine: vm)
  let context2 = JSContext(virtualMachine: vm)

  #expect(context1 == context1)
  #expect(context1 != context2)

  await context1.withIsolatedGlobalObject { context, global in
    let isObject = global.isObject(in: context)
    let type = global.type(in: context)
    #expect(isObject)
    #expect(type == .object)
  }
}

@Test func valueInitializersAndTypePredicates() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let undefined = JSValue(undefinedIn: context)
    let null = JSValue(nullIn: context)
    let bool = JSValue(boolean: true, in: context)
    let number = JSValue(number: 42, in: context)
    let string = JSValue(string: "abc", in: context)
    let symbol = JSValue(symbol: "s", in: context)
    let intNumber = JSValue(number: 7 as Int, in: context)

    let undefinedIsUndefined = undefined.isUndefined(in: context)
    let undefinedType = undefined.type(in: context)
    #expect(undefinedIsUndefined)
    #expect(undefinedType == .undefined)

    let nullIsNull = null.isNull(in: context)
    let nullType = null.type(in: context)
    #expect(nullIsNull)
    #expect(nullType == .null)

    let boolIsBoolean = bool.isBoolean(in: context)
    let boolType = bool.type(in: context)
    #expect(boolIsBoolean)
    #expect(boolType == .boolean)

    let numberIsNumber = number.isNumber(in: context)
    let numberType = number.type(in: context)
    #expect(numberIsNumber)
    #expect(numberType == .number)

    let stringIsString = string.isString(in: context)
    let stringType = string.type(in: context)
    #expect(stringIsString)
    #expect(stringType == .string)

    let symbolIsSymbol = symbol.isSymbol(in: context)
    let symbolType = symbol.type(in: context)
    #expect(symbolIsSymbol)
    #expect(symbolType == .symbol)

    let intIsNumber = intNumber.isNumber(in: context)
    let intIsBigInt = intNumber.isBigInt(in: context)
    #expect(intIsNumber)
    #expect(!intIsBigInt)
  }
}

@Test func valueEqualityOperators() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, _ in
    let oneNumber = JSValue(number: 1, in: context)
    let oneString = JSValue(string: "1", in: context)
    let oneNumberCopy = JSValue(number: 1, in: context)

    let looselyEqual = oneNumber.looselyEquals(oneString, in: context)
    let looselyNotEqual = !oneNumber.looselyEquals(
      JSValue(number: 2, in: context), in: context)
    let strictlyEqual = oneNumber.strictlyEquals(oneNumberCopy, in: context)
    let strictlyNotEqual = !oneNumber.strictlyEquals(
      JSValue(number: 2, in: context), in: context)

    #expect(looselyEqual)
    #expect(looselyNotEqual)
    #expect(strictlyEqual)
    #expect(strictlyNotEqual)
  }
}

@Test func valuesCanBeUsedAcrossContextsInSameVirtualMachine() {
  let vm = JSVirtualMachine<JavaScriptCoreEngine>()
  let sourceContext = JSContext(virtualMachine: vm)
  let targetContext = JSContext(virtualMachine: vm)

  let sourceInstant = JSInstantContext<JavaScriptCoreEngine>(
    ctx: sourceContext.javaScriptCoreContextRef)
  let targetInstant = JSInstantContext<JavaScriptCoreEngine>(
    ctx: targetContext.javaScriptCoreContextRef)
  let value = JSValue(number: 7, in: sourceInstant)

  #expect(value.toDouble(in: targetInstant) == 7)
}
