import Testing

@testable import SwiftyJavaScriptCore

@Test func javaScriptCoreValueHandleStorageRoundTripsPointerWords() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withInstantContext { context in
    let value = JSValue(number: 42, in: context)
    let handle = value.borrowHandle()
    let storageWords = JavaScriptCoreEngine.makeStorageWords(
      value: handle, in: context.driverContextHandle)

    let (restored, restoredContext) = JavaScriptCoreEngine.fromStorageWords(storageWords)
    #expect(restored.ref == handle.ref)

    let reboundStorageWords = JavaScriptCoreEngine.makeStorageWords(
      value: restored, in: restoredContext)
    #expect(reboundStorageWords.word0 == storageWords.word0)
    #expect(reboundStorageWords.word1 == storageWords.word1)
    #expect(reboundStorageWords.word2 == storageWords.word2)
  }
}
