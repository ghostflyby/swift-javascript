import Testing

@testable import SwiftyJavaScriptCore

@Test func codableConverterRoundtripDirectObjectGraph() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

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
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("user"),
      using: JSCodableValueConverter<CodableUser>.self,
      in: context
    )

    let decoded: CodableUser = global.getProperty(
      forKey: SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("user"),
      using: JSCodableValueConverter<CodableUser>.self,
      in: context
    )

    #expect(decoded == user)
  }
}
