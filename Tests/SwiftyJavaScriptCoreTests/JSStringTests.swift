import Testing

@testable import SwiftyJavaScriptCore

@Test func stringInitFromJSStringHandle() {
  let managed = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("hello")
  let swiftString = String(
    jsStringHandle: managed.jsStringHandle,
    engine: JavaScriptCoreEngine.self
  )

  #expect(swiftString == "hello")
}

@Test func jsStringManagedBasics() {
  let value = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("abc")

  #expect(value.string == "abc")
  #expect(value.cached == "abc")
}

@Test func jsStringManagedEmpty() {
  #expect(SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>.empty.string == "")
}

@Test func jsStringGroupInitAndEquality() {
  let managed = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("group")
  let grouped = SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>(group: managed)

  let eq1 = grouped == managed
  let ne = grouped != SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("other")

  #expect(eq1)
  #expect(ne)
}

@Test func jsStringValueInitsAndCaching() {
  let base = SwiftJavaScript.JSStringValue<JavaScriptCoreEngine>("cache")
  let noCache = SwiftJavaScript.JSStringValue<JavaScriptCoreEngine>(base, caching: false)
  let withCache = SwiftJavaScript.JSStringValue<JavaScriptCoreEngine>(base, caching: true)
  let fromManaged = SwiftJavaScript.JSStringValue<JavaScriptCoreEngine>(
    SwiftJavaScript.JSStringManaged<JavaScriptCoreEngine>("m"), caching: true)

  let baseCached = base.cached
  let noCacheString = noCache.string
  let withCacheCached = withCache.cached
  let fromManagedCached = fromManaged.cached

  #expect(baseCached == "cache")
  #expect(noCacheString == "cache")
  #expect(withCacheCached == "cache")
  #expect(fromManagedCached == "m")
}
