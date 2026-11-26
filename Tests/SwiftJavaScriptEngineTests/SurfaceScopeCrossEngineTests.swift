import SwiftyJavaScriptCore
import SwiftyQuickJS
import Testing

@testable import SwiftJavaScript

// MARK: - Surface scope protocol defaults across both engines (S7)
//
// Both engines run the same generic assertions: the `JSInstantContext`
// requirements and the `~Copyable` protocol defaults (global property access,
// encoder-based writes, script evaluation, decoder witnesses, the default
// converter) must behave identically rather than relying on an
// engine-specific path.

private struct SurfaceScopeCrossPayload: Codable, Equatable {
  var name: String
  var values: [Int]
}

private func assertSurfaceScopeDefaults<S: JSInstantContext & ~Copyable>(
  _ scope: borrowing S
) {
  let text = scope.makeString("generic")
  let textType = text.type()
  #expect(textType == .string)

  // Encoder witnesses through the generic window.
  let encodedString = "encoded".toSurfaceValue(in: scope)
  let encodedStringText = encodedString.toString()
  #expect(encodedStringText == "encoded")

  let encodedBool = true.toSurfaceValue(in: scope)
  let encodedBoolType = encodedBool.type()
  #expect(encodedBoolType == .boolean)

  // Global property defaults (`setGlobalProperty`/`hasGlobalProperty`/
  // `getGlobalProperty`/`deleteGlobalProperty`) are protocol extensions.
  let key: StaticString = "surfaceCrossKey"
  scope.setGlobalProperty(scope.makeNumber(3), forKey: key)
  let hasKey = scope.hasGlobalProperty(key)
  let readNumber = scope.getGlobalProperty(forKey: key).toNumber()
  #expect(hasKey)
  #expect(readNumber == 3)

  scope.deleteGlobalProperty(forKey: key)
  let hasAfterDelete = scope.hasGlobalProperty(key)
  #expect(!hasAfterDelete)

  // Script evaluation default (`String` form prepares a script first).
  let scriptResult = scope.evaluateScript("1 + 1")
  switch consume scriptResult {
  case .value(let value):
    let sum = value.toNumber()
    #expect(sum == 2)
  case .exception:
    Issue.record("surface scope script evaluation threw")
  }

  // Callback-exit defaults on the ~Copyable protocol.
  let returned = scope.return(text)
  let returnedIsException = returned.isException
  #expect(!returnedIsException)

  let thrown = scope.throw(text)
  let thrownIsException = thrown.isException
  #expect(thrownIsException)

  let undefinedReturn = scope.returnUndefined()
  let undefinedReturnIsException = undefinedReturn.isException
  #expect(!undefinedReturnIsException)

  // Decoder witness over the surface value.
  let number = scope.persist(scope.makeNumber(4.5))
  let decodedNumber = try? Double.tryDecode(number, in: scope)
  #expect(decodedNumber == 4.5)

  // Default converter routes through the surface protocols.
  let defaultEncoded = JSDefaultConverter<String>.encode("default", in: scope)
  let defaultText = defaultEncoded.toString()
  #expect(defaultText == "default")
  let defaultDecoded = try? JSDefaultConverter<String>.tryDecode(
    defaultEncoded,
    in: scope
  )
  #expect(defaultDecoded == "default")

  // Codable object traversal through the generic window.
  let payload = SurfaceScopeCrossPayload(name: "cross", values: [1, 2, 3])
  let encodedPayload = try? JSCodableValueConverter<SurfaceScopeCrossPayload>.tryEncode(
    payload,
    in: scope
  )
  guard let encodedPayload else {
    Issue.record("Codable surface encoding returned nil")
    return
  }
  let decodedPayload = try? JSCodableValueConverter<SurfaceScopeCrossPayload>.tryDecode(
    encodedPayload,
    in: scope
  )
  #expect(decodedPayload == payload)
}

@Test func javaScriptCoreSurfaceScopeProtocolDefaults() async {
  let context = JSCContext()
  await context.withInstantContext { scope in
    assertSurfaceScopeDefaults(scope)
  }
}

@Test func quickJSSurfaceScopeProtocolDefaults() async {
  let context = QJSContext()
  await context.withInstantContext { scope in
    assertSurfaceScopeDefaults(scope)
  }
}
