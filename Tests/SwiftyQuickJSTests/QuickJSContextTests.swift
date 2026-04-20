import Testing

@testable import SwiftyQuickJS

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
  typealias CQuickJSValue = CQuickJSStatic.JSValue
  typealias CQuickJSValueUnion = CQuickJSStatic.JSValueUnion
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
  typealias CQuickJSValue = CQuickJSDynamic.JSValue
  typealias CQuickJSValueUnion = CQuickJSDynamic.JSValueUnion
#endif

@Test func quickJSValueHandleStorageRoundTripsTagUnionAndContextWords() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withInstantContext { context in
    let value = context.makeNumber(42)
    let handle = value.borrowHandle()
    let storageWords = handle.storageWords

    #expect(storageWords.word0 == UInt64(bitPattern: handle.ref.tag))
    #expect(storageWords.word2 == UInt64(UInt(bitPattern: handle.contextRef)))

    let restored = QuickJSValueHandle(storageWords: storageWords)
    #expect(restored.ref.tag == handle.ref.tag)
    #expect(restored.contextRef == handle.contextRef)

    let reboundStorageWords = restored.storageWords
    #expect(reboundStorageWords.word0 == storageWords.word0)
    #expect(reboundStorageWords.word1 == storageWords.word1)
    #expect(reboundStorageWords.word2 == storageWords.word2)
  }
}

@Test func quickJSHandleStorageWordsLayout() {
  #expect(MemoryLayout<CQuickJSValue>.stride == 2 * MemoryLayout<UInt64>.stride)
  #expect(MemoryLayout<CQuickJSValueUnion>.size == MemoryLayout<UInt64>.size)
}
