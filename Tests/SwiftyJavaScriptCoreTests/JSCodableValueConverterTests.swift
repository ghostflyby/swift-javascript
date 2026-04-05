import Testing

@testable import SwiftyJavaScriptCore

@Test func codableConverterRoundtripDirectObjectGraph() async {
  let context = JSContext(virtualMachine: JSEngineVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let user = CodableUser(
      name: "alice",
      age: 30,
      active: true,
      tags: ["swift", "jsc"],
      address: CodableAddress(city: "shanghai", zip: 200000)
    )

    global.setProperty(
      user,
      forKey: JSStringManaged("user"),
      using: JSCodableValueConverter<CodableUser>.self,
      in: context
    )

    let decoded: CodableUser = global.getProperty(
      forKey: JSStringManaged("user"),
      using: JSCodableValueConverter<CodableUser>.self,
      in: context
    )

    #expect(decoded == user)
  }
}
