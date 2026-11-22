import Foundation
import Synchronization
import Testing

@testable import SwiftJavaScript

// MARK: - Stage 2A negative compile examples (not automatable in Swift Testing)
//
// 「owned handle 被复制/存入集合应编译失败」是编译期契约:Swift Testing 无法
// 在测试内断言编译期失败(需要独立的负面编译用例),以下样例仅以文档形式
// 保留,标注「应编译失败」,该验证未自动化:
//
//     func sink(_ handle: consuming MockOwnedValueHandle) {}
//
//     let owned = MockOwnedValueHandle(
//       rawValue: MockValue(kind: "string", payload: "owned"))
//
//     // ✗ 应编译失败 —— owned handle 是 ~Copyable 所有权载体(SE-0503),
//     // 同一 owning 引用只能存在于一处:第二处独立(消耗性)使用意味着
//     // 前面的绑定必须是复制:
//     let duplicate = owned
//     sink(duplicate)
//     sink(owned)
//
//     // ✗ 应编译失败(复制的另一形态)——消耗性移交后原绑定继续使用:
//     sink(owned)
//     _ = owned.borrowed()
//
//     // ✗ 应编译失败 —— ~Copyable 值不能作为集合元素(数组要求元素
//     // Copyable),存入集合即隐式复制:
//     var bucket: [MockOwnedValueHandle] = []
//     bucket.append(owned)
//
// 注意:仅当原绑定此后不再使用时,`let duplicate = owned` 才被编译器当作重
// 绑定接受、不构成复制;原绑定与新绑定同为借用性使用仍会编译失败——复制负
// 样例必须以独立/消耗性使用呈现。
//
// 借用侧 `MockValueHandle` 是 Copyable 身份 token,复制/入集合合法且无副
// 作用;两侧之间的所有权流转只能经显式转换——`borrowed()` 降级(不释放)、
// `adopting(_:)` 升级(不改引用计数)。
//
// 构建探针实测结论(2026-11-22,Apple Swift 6.4.2 / swiftlang-6.4.2.1.9;
// 探针文件临时加入 `SwiftJavaScriptTests` target 后 `swift build --build-tests`,
// 复制/入集合两类样例分别构建,验证后删除探针并重建通过):
// - 复制样例(`sink(duplicate); sink(owned)`)报
//   error: 'owned' consumed more than once;
// - 复制样例(`sink(owned)` 后 `owned.borrowed()`)报
//   error: 'owned' used after consume;
// - 入集合样例(`[MockOwnedValueHandle]`)报
//   error: type 'MockOwnedValueHandle' does not conform to protocol 'Copyable'。

public struct MockRuntime: Sendable, Equatable {
  let id: String
}

// MARK: - Arena tracking counter for MockEngine

private let mockReleaseCounter = Mutex<[MockValueHandle]>([])

private func takeReleasedHandles() -> [MockValueHandle] {
  mockReleaseCounter.withLock {
    let result = Array($0)
    $0.removeAll()
    return result
  }
}

public struct MockRuntimeHandle: JSRuntimeManualReferenceCountedHandle, @unchecked Sendable {
  let rawRuntime: MockRuntime

  init(rawRuntime: MockRuntime) {
    self.rawRuntime = rawRuntime
  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  public func retainReference() -> Bool {
    true
  }

  public func releaseReference() -> Bool {
    true
  }
}

public struct MockContext: Sendable, Hashable {
  let runtimeID: String
  let identity: String

  init(runtimeID: String, identity: String = "") {
    self.runtimeID = runtimeID
    self.identity = identity.isEmpty ? runtimeID : identity
  }
}

public struct MockContextHandle: JSContextManualReferenceCountedHandle, @unchecked Sendable,
  Hashable
{
  let rawContext: MockContext

  init(rawContext: MockContext) {
    self.rawContext = rawContext
  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  public func retainReference() -> Bool {
    true
  }

  public func releaseReference() -> Bool {
    true
  }
}

private struct MockContextDataRegistryKey: Hashable, Sendable {
  let identity: String
}

private let mockContextDataStorageRegistry =
  Mutex<[MockContextDataRegistryKey: JSContextDataStorageBox]>([:])

private func mockContextDataRegistryKey(
  for context: MockContextHandle
) -> MockContextDataRegistryKey {
  MockContextDataRegistryKey(identity: context.rawContext.identity)
}

private func mockContextDataStorage(
  for context: MockContextHandle
) -> JSContextDataStorageBox {
  let key = mockContextDataRegistryKey(for: context)
  return mockContextDataStorageRegistry.withLock {
    if let existing = $0[key] {
      return existing
    }
    let created = JSContextDataStorageBox()
    $0[key] = created
    return created
  }
}

public struct MockValue: Sendable, Equatable {
  let kind: String
  let payload: String
}

private final class MockValueHandleStorage: @unchecked Sendable {
  let rawValue: MockValue
  private let onReleaseReference: (@Sendable () -> Void)?

  init(rawValue: MockValue, onReleaseReference: (@Sendable () -> Void)? = nil) {
    self.rawValue = rawValue
    self.onReleaseReference = onReleaseReference
  }

  func recordReleaseReference() {
    onReleaseReference?()
  }
}

private final class MockValueReleaseCounter: @unchecked Sendable {
  private(set) var releaseReferenceCount = 0

  func increment() {
    releaseReferenceCount += 1
  }
}

public struct MockClass: Sendable, Equatable, Hashable {
  let id: String
}

public struct MockClassHandle: JSClassManualReferenceCountedHandle, @unchecked Sendable,
  Equatable, Hashable
{
  let rawClass: MockClass

  init(rawClass: MockClass) {
    self.rawClass = rawClass
  }

  public func retainReference() -> Bool {
    true
  }

  public func releaseReference() -> Bool {
    true
  }
}

public final class MockStringHandle: JSPropertyStringKeyManualReferenceCountedHandle,
  JSPreparedScriptManualReferenceCountedHandle, @unchecked Sendable
{
  private let count: Int
  private let storage: UnsafeMutablePointer<UInt16>

  init(_ value: String) {
    let units = Array(value.utf16)
    count = units.count
    storage = .allocate(capacity: max(1, count))
    if count > 0 {
      storage.initialize(from: units, count: count)
    }
  }

  deinit {
    if count > 0 {
      storage.deinitialize(count: count)
    }
    storage.deallocate()
  }

  var length: Int { count }

  var characters: UnsafePointer<UInt16> {
    UnsafePointer(storage)
  }

  var string: String {
    String(decoding: UnsafeBufferPointer(start: characters, count: count), as: UTF16.self)
  }

  @discardableResult
  public func retainReference() -> Bool {
    true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    true
  }
}

public struct MockValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  typealias Engine = MockEngine
  typealias RawValue = MockValue
  public typealias Context = MockContextHandle

  let storagePointer: UnsafeMutableRawPointer

  var rawValue: MockValue {
    Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue().rawValue
  }

  init(rawValue: MockValue) {
    self.init(rawValue: rawValue, onRelease: nil)
  }

  init(storagePointer: UnsafeMutableRawPointer) {
    self.storagePointer = storagePointer
  }

  private init(rawValue: MockValue, onRelease: (@Sendable () -> Void)?) {
    self.storagePointer = Unmanaged.passRetained(
      MockValueHandleStorage(rawValue: rawValue, onReleaseReference: onRelease)
    ).toOpaque()
  }

  static func releaseCounting(
    rawValue: MockValue,
    onRelease: @escaping @Sendable () -> Void
  ) -> MockValueHandle {
    MockValueHandle(rawValue: rawValue, onRelease: onRelease)
  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  public typealias Owned = MockOwnedValueHandle

  public func retainReference(in: Context) {
    let storage = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue()
    _ = Unmanaged.passRetained(storage)
  }

  public func releaseReference(in: Context) {
    let storage = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue()
    storage.recordReleaseReference()
    _ = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeRetainedValue()
  }
}

/// `~Copyable` ownership carrier mirroring the engine backends' owned
/// handles: wraps the same `MockValueHandleStorage` identity so
/// `borrowed()`/`adopting(_:)` round-trip the release-counting hooks.
public struct MockOwnedValueHandle: JSOwnedValueManualReferenceCountedHandle, Equatable, ~Copyable {
  public typealias Context = MockContextHandle
  public typealias Borrowed = MockValueHandle

  let storagePointer: UnsafeMutableRawPointer

  init(rawValue: MockValue) {
    self.storagePointer = Unmanaged.passRetained(
      MockValueHandleStorage(rawValue: rawValue, onReleaseReference: nil)
    ).toOpaque()
  }

  init(storagePointer: UnsafeMutableRawPointer) {
    self.storagePointer = storagePointer
  }

  var rawValue: MockValue {
    Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue().rawValue
  }

  public borrowing func borrowed() -> MockValueHandle {
    MockValueHandle(storagePointer: storagePointer)
  }

  public static func adopting(_ handle: borrowing MockValueHandle) -> MockOwnedValueHandle {
    MockOwnedValueHandle(storagePointer: handle.storagePointer)
  }
}

public enum MockEngine: JSEngine {
  public typealias RuntimeHandle = MockRuntimeHandle
  public typealias ContextHandle = MockContextHandle
  public typealias ValueHandle = MockValueHandle
  public typealias OwnedValueHandle = MockOwnedValueHandle
  public typealias ClassHandle = MockClassHandle
  public typealias PropertyStringKeyHandle = MockStringHandle
  public typealias PreparedScriptHandle = MockStringHandle

  public static func isContextCompatibleWith(_ this: MockContextHandle, _ that: MockContextHandle)
    -> Bool
  {
    true
  }

  public static func releaseCreatedHandle(
    _ handle: consuming MockOwnedValueHandle, in context: MockContextHandle
  ) {
    contextReleaseLog.withLock {
      $0[context.rawContext.identity, default: []].append(handle.borrowed())
    }
  }
}

// MARK: - Arena lifecycle tests

@Test func scopeArenaReleasesAbandonedValuesOnDeinit() {
  let id = "scopeArenaReleasesAbandoned"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    _ = scope.makeString("a")
    _ = scope.makeNumber(42)
    _ = scope.makeBoolean(true)
    #expect(releaseLog(for: id).isEmpty)
  }

  #expect(releaseLog(for: id).count == 3)
}

@Test func scopeArenaSkipsPersistedValuesOnDeinit() {
  let id = "scopeArenaSkipsPersisted"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  var persisted: JSValue<MockEngine>? = nil
  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    persisted = scope.persist(scope.makeString("keep"))
  }

  // persist 摘除创建引用不结算(已知 +1 泄漏,排期 §3.7 Rooting);JSValue 自持引用不在此路径释放。
  #expect(releaseLog(for: id).count == 0)
  _ = persisted
}

@Test func scopeArenaBorrowingReturnDoesNotRemoveFromArena() {
  let id = "scopeArenaBorrowingReturn"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    _ = scope.return(scope.makeString("temp"))
  }

  #expect(releaseLog(for: id).count == 1)
}

@Test func scopeArenaMixedLifecycle() {
  let id = "scopeArenaMixed"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  var persisted: JSValue<MockEngine>? = nil
  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    let a = scope.makeString("abandoned")
    _ = scope.return(scope.makeNumber(1))  // borrowing → stays
    persisted = scope.persist(a)  // persisted → creation reference removed (unsettled, known leak)
    _ = scope.makeBoolean(false)  // abandoned
  }

  _ = persisted
  #expect(releaseLog(for: id).count == 2)  // number + boolean
}

// MARK: - Stage 2A owned-element arena tests

/// 与实现侧 chunk 容量保持一致(ScopeArena 每 chunk 32 槽,见
/// JSInstantContext.swift 的 scopeArenaChunkCapacity)。
private let stage2AArenaChunkCapacity = 32

/// 跨 chunk 边界的 drain:arena 以 32 槽 chunk 链分块持有 owned 元素,
/// drain 必须把每个 owned 元素恰好释放一次(不泄漏、不重复)。
@Test func scopeArenaDrainsOwnedElementsAcrossChunkBoundaries() {
  let id = "scopeArenaDrainsAcrossChunks"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))
  let total = stage2AArenaChunkCapacity + 5  // 首块 32 槽 + 次块 5 槽

  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    for index in 0..<total {
      _ = scope.makeNumber(Double(index))
    }
    #expect(releaseLog(for: id).isEmpty)
  }

  let released = releaseLog(for: id)
  #expect(released.count == total)
  // 释放条目两两不同(每个 owned 身份恰好一次)且负载与创建集合一致。
  #expect(Set(released).count == total)
  #expect(
    Set(released.map(\.rawValue.payload))
      == Set((0..<total).map { "\(id):\(Double($0))" }))
}

/// persist 摘除埋在非头 chunk 的元素:洞由 arena 最后一个元素(跨 chunk)
/// 回填;被摘除的创建引用在 persist 时结算入账(恰好一次),drain 释放其余全部。
@Test func scopeArenaPersistRemovesOwnedElementBuriedInOldestChunk() {
  let id = "scopeArenaPersistBuriedInOldestChunk"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))
  let overflow = stage2AArenaChunkCapacity  // "keep" 之后 32 个:恰好溢出到第二 chunk

  let keepHandle: MockValueHandle
  var persisted: JSValue<MockEngine>? = nil
  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    let keep = scope.makeString("keep")  // 位于最老 chunk 的槽 0
    keepHandle = keep.handle
    for index in 0..<overflow {
      _ = scope.makeNumber(Double(index))
    }
    // persist 按身份摘除:removeFirst 匹配到最老 chunk 槽 0,
    // 用 arena 最后一个元素(位于头 chunk)回填;创建引用摘除不结算(已知泄漏)。
    persisted = scope.persist(JSCallbackValue(handle: keepHandle, context: context))
  }

  let released = releaseLog(for: id)
  #expect(released.count == overflow)
  #expect(!released.contains(keepHandle))
  #expect(released.allSatisfy { $0.rawValue.kind == "number" })
  _ = persisted
}

/// persist 摘除头 chunk 中间的元素:洞由 arena 最后一个元素(同 chunk)回填,
/// 排列变化不影响释放账目——其余元素各恰好释放一次。
@Test func scopeArenaPersistMiddleElementBackfillsArenaLastIntoHole() {
  let id = "scopeArenaPersistMiddleBackfill"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  let middleHandle: MockValueHandle
  var persisted: JSValue<MockEngine>? = nil
  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    _ = scope.makeString("first")
    let middle = scope.makeString("middle")
    middleHandle = middle.handle
    _ = scope.makeString("last")
    persisted = scope.persist(JSCallbackValue(handle: middleHandle, context: context))
  }

  let released = releaseLog(for: id)
  #expect(released.count == 2)
  #expect(!released.contains(middleHandle))
  #expect(Set(released.map(\.rawValue.payload)) == ["\(id):first", "\(id):last"])
  _ = persisted
}

/// 拆分后(Stage 2A)引擎操作结果的落账行为不变:getProperty 返回的 +1 结
/// 果经 `JSOwnedValueHandle.adopting` 升级后 track 到栈顶 arena,drain 时该
/// 身份恰好释放一次——既不泄漏(0 次)也不双释放(2 次)。
@Test func callbackValueOperationResultIsAdoptedAndReleasedExactlyOnce() {
  let id = "scopeArenaOperationResultAdopted"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  var resultHandle: MockValueHandle? = nil
  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    let base = scope.makeString("base")
    switch base.getProperty("routed") {
    case .value(let property):
      resultHandle = property.handle
    case .exception:
      Issue.record("Expected getProperty to succeed")
    }
    #expect(releaseLog(for: id).isEmpty)  // scope 未关,base 与结果都在账上
  }

  let released = releaseLog(for: id)
  #expect(released.count == 2)  // base 值 + getProperty 结果
  if let resultHandle {
    #expect(released.filter { $0 == resultHandle }.count == 1)
  }
}

/// `makeString(from:)`(property-string-key 工厂,Stage 2A 起返回 Owned 形
/// 态)的产物入账 arena 并随 drain 释放一次,内容按 key 字符串构造。
@Test func scopeArenaTracksStringCreatedFromPropertyStringKey() {
  let id = "scopeArenaPropertyStringKeyString"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  do {
    let scope = JSInstantContext<MockEngine>(handle: context)
    let key = scope.makePropertyStringKey("key-text")
    let made = scope.makeString(from: key)
    #expect(made.handle.rawValue == MockValue(kind: "string", payload: "\(id):key-text"))
    #expect(releaseLog(for: id).isEmpty)
  }

  #expect(releaseLog(for: id).count == 1)
}

// MARK: - JSScope arena lifecycle tests

@Test func jsScopeArenaReleasesAbandonedValuesOnDeinit() {
  let id = "jsScopeArenaReleasesAbandoned"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  do {
    var scope = JSScope<MockEngine>(handle: context)
    scope.open()
    _ = scope.makeString("a")
    _ = scope.makeNumber(42)
    _ = scope.makeBoolean(true)
    #expect(releaseLog(for: id).isEmpty)
  }

  #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
  #expect(releaseLog(for: id).count == 3)
}

@Test func jsScopeArenaSkipsPersistedValuesOnDeinit() {
  let id = "jsScopeArenaSkipsPersisted"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  var persisted: JSValue<MockEngine>? = nil
  do {
    var scope = JSScope<MockEngine>(handle: context)
    scope.open()
    persisted = scope.persist(scope.makeString("keep"))
  }

  #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
  // persist 摘除创建引用不结算(已知 +1 泄漏,排期 §3.7 Rooting);JSValue 自持引用不在此路径释放。
  #expect(releaseLog(for: id).count == 0)
  _ = persisted
}

@Test func jsScopeArenaMixedLifecycle() {
  let id = "jsScopeArenaMixed"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  var persisted: JSValue<MockEngine>? = nil
  do {
    var scope = JSScope<MockEngine>(handle: context)
    scope.open()
    let a = scope.makeString("abandoned")
    persisted = scope.persist(a)  // persisted → creation reference removed (unsettled, known leak)
    _ = scope.makeNumber(1)  // abandoned
    _ = scope.makeBoolean(false)  // abandoned
  }

  _ = persisted
  #expect(releaseLog(for: id).count == 2)  // number + boolean
}

@Test func jsScopeWithoutOpenDoesNotPushScopeStack() {
  let id = "jsScopeWithoutOpen"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
  do {
    let scope = JSScope<MockEngine>(handle: context)
    #expect(scope.driverContextHandle == context)
    #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
  }

  #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
  #expect(releaseLog(for: id).isEmpty)
}

@Test func jsScopeFactoriesWorkAfterOpen() {
  let id = "jsScopeFactoriesWork"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  do {
    var scope = JSScope<MockEngine>(handle: context)
    scope.open()
    #expect(ScopeStackRegistry<MockEngine>.top(of: context) != nil)

    let string = scope.makeString("hello")
    #expect(string.handle.rawValue == MockValue(kind: "string", payload: "\(id):hello"))

    switch scope.makeObject() {
    case .value(let object):
      #expect(object.handle.rawValue == MockValue(kind: "object", payload: id))
    case .exception:
      Issue.record("Expected makeObject to succeed")
    }

    #expect(releaseLog(for: id).isEmpty)
  }

  #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
  #expect(releaseLog(for: id).count == 2)  // string + object drained
}

// MARK: - Context-addressed scope stack tests (Stage 1, §3.4)

/// 同线程先后使用两个不同 context 的 scope,互不串扰(取代旧 TLS 语义的回归):
/// 作用域栈按 context 挂载,值的释放与操作路由都落在各自 context 上。
@Test func sameThreadScopesOnDistinctContextsDoNotCrossTalk() {
  let idA = "scopeStackSequentialA"
  let idB = "scopeStackSequentialB"
  clearReleaseLog(for: idA)
  clearReleaseLog(for: idB)
  let contextA = MockContextHandle(rawContext: MockContext(runtimeID: idA))
  let contextB = MockContextHandle(rawContext: MockContext(runtimeID: idB))

  do {
    let scopeA = JSInstantContext<MockEngine>(handle: contextA)
    #expect(ScopeStackRegistry<MockEngine>.top(of: contextA) != nil)
    let valueFromA = scopeA.makeString("made-in-A")
    // MockDriver 的操作路由在 payload 中带上操作时寻址的 context:
    // getProperty 必须经 valueFromA 自带的 contextHandle 寻址到 A。
    switch valueFromA.getProperty("routed") {
    case .value(let property):
      #expect(property.toString() == "\(idA):\(idA):made-in-A:routed")
    case .exception:
      Issue.record("Expected getProperty to succeed in scope A")
    }
    _ = scopeA.makeNumber(1)
  }
  #expect(ScopeStackRegistry<MockEngine>.top(of: contextA) == nil)
  #expect(releaseLog(for: idA).count == 3)  // string + getProperty result + number
  #expect(releaseLog(for: idB).isEmpty)

  do {
    let scopeB = JSInstantContext<MockEngine>(handle: contextB)
    #expect(ScopeStackRegistry<MockEngine>.top(of: contextB) != nil)
    let valueFromB = scopeB.makeString("made-in-B")
    switch valueFromB.getProperty("routed") {
    case .value(let property):
      #expect(property.toString() == "\(idB):\(idB):made-in-B:routed")
    case .exception:
      Issue.record("Expected getProperty to succeed in scope B")
    }
  }
  #expect(ScopeStackRegistry<MockEngine>.top(of: contextB) == nil)
  #expect(releaseLog(for: idA).count == 3)  // A 的账目不受 B 的影响
  #expect(releaseLog(for: idB).count == 2)  // string + getProperty result
}

/// 同线程上重叠开启两个不同 context 的 scope:B 的 scope 关闭时不得消费 A 的
/// 栈帧或释放 A 的值;A 创建的值在 B 的 scope 打开期间仍可用,且其操作仍
/// 经自带的 contextHandle 寻址到 A(旧 TLS 实现下线程栈顶是 B,会错误地
/// 把 A 的值解析到 B)。
@Test func overlappingSameThreadScopesOnDistinctContextsReleaseToTheirOwnContexts() {
  let idA = "scopeStackOverlapA"
  let idB = "scopeStackOverlapB"
  clearReleaseLog(for: idA)
  clearReleaseLog(for: idB)
  let contextA = MockContextHandle(rawContext: MockContext(runtimeID: idA))
  let contextB = MockContextHandle(rawContext: MockContext(runtimeID: idB))

  do {
    let scopeA = JSInstantContext<MockEngine>(handle: contextA)
    let valueFromA = scopeA.makeString("still-alive")

    do {
      let scopeB = JSInstantContext<MockEngine>(handle: contextB)
      let valueFromB = scopeB.makeString("made-in-B")

      // B 的 scope 是同线程上最新开启的,A 的值仍存活、可用,
      // 且 getProperty 经值自带的 contextHandle 寻址到 A 而非栈顶的 B。
      switch valueFromA.getProperty("routed") {
      case .value(let property):
        #expect(property.toString() == "\(idA):\(idA):still-alive:routed")
      case .exception:
        Issue.record("Expected A's value to stay addressable while B's scope is open")
      }
      switch valueFromB.getProperty("routed") {
      case .value(let property):
        #expect(property.toString() == "\(idB):\(idB):made-in-B:routed")
      case .exception:
        Issue.record("Expected getProperty to succeed in scope B")
      }
      #expect(releaseLog(for: idA).isEmpty)
      #expect(releaseLog(for: idB).isEmpty)
    }

    // B 关闭:只释放 B 的值与 B 的操作结果,不动 A 的账目。
    #expect(releaseLog(for: idA).isEmpty)
    #expect(releaseLog(for: idB).count == 2)  // B value + B-routed result
    #expect(valueFromA.toString() == "\(idA):still-alive")
  }

  #expect(releaseLog(for: idA).count == 2)  // A value + A-routed result
  #expect(releaseLog(for: idB).count == 2)
  #expect(ScopeStackRegistry<MockEngine>.top(of: contextA) == nil)
  #expect(ScopeStackRegistry<MockEngine>.top(of: contextB) == nil)
}

/// 同 context 嵌套契约(§3.4):外层 scope 创建的值在内层 scope 打开期间
/// 保持可用;操作结果按该 context 的栈顶(内层)落账,内层 drain 只释放
/// 落账在内层 arena 的结果,不动外层创建的值。
@Test func nestedSameContextScopesKeepOuterValuesAlive() {
  let id = "scopeStackNestedSameContext"
  clearReleaseLog(for: id)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: id))

  do {
    let outer = JSInstantContext<MockEngine>(handle: context)
    let outerValue = outer.makeString("outer")
    do {
      let inner = JSInstantContext<MockEngine>(handle: context)
      #expect(ScopeStackRegistry<MockEngine>.top(of: context) != nil)
      switch outerValue.getProperty("routed") {
      case .value(let property):
        #expect(property.toString() == "\(id):\(id):outer:routed")
      case .exception:
        Issue.record("Expected outer value to stay usable while inner scope is open")
      }
      #expect(releaseLog(for: id).isEmpty)  // 内层未关,外层值与结果都在账上
    }
    // 内层关闭:释放落账在内层的 getProperty 结果,不动外层创建的值。
    #expect(releaseLog(for: id).count == 1)
    #expect(outerValue.toString() == "\(id):outer")  // 外层值仍可用
  }

  #expect(releaseLog(for: id).count == 2)  // 外层值随外层 drain 释放
  #expect(ScopeStackRegistry<MockEngine>.top(of: context) == nil)
}

@Test func jsValueDeinitReleasesHandleExactlyOnce() {
  let counter = MockValueReleaseCounter()
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "test"))

  do {
    let value = JSValue<MockEngine>(
      handleValue: .releaseCounting(
        rawValue: MockValue(kind: "object", payload: "deinit"),
        onRelease: counter.increment
      ),
      in: context
    )
    #expect(value.borrowHandle().rawValue.payload == "deinit")
    #expect(counter.releaseReferenceCount == 0)
  }

  #expect(counter.releaseReferenceCount == 1)
}

@Test func jsValueRetainedCopyDeinitReleasesEachWrapper() {
  let counter = MockValueReleaseCounter()
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "test"))

  do {
    let value = JSValue<MockEngine>(
      handleValue: .releaseCounting(
        rawValue: MockValue(kind: "object", payload: "retained"),
        onRelease: counter.increment
      ),
      in: context
    )

    do {
      let retained = JSValue<MockEngine>(retaining: value)
      #expect(retained.borrowHandle().rawValue.payload == "retained")
      #expect(counter.releaseReferenceCount == 0)
    }

    #expect(counter.releaseReferenceCount == 1)
  }

  #expect(counter.releaseReferenceCount == 2)
}

@Test func jsValueTakeHandleSkipsDeinitUntilHandleRelease() {
  let counter = MockValueReleaseCounter()
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "test"))

  let value = JSValue<MockEngine>(
    handleValue: .releaseCounting(
      rawValue: MockValue(kind: "object", payload: "transfer"),
      onRelease: counter.increment
    ),
    in: context
  )
  let transferredHandle = value.takeHandle()

  #expect(counter.releaseReferenceCount == 0)
  transferredHandle.releaseReference(in: context)
  #expect(counter.releaseReferenceCount == 1)
}

private enum MockDriver: JSEngine {
  static func isContextCompatibleWith(_ this: MockContextHandle, _ that: MockContextHandle) -> Bool
  {
    return true
  }

  typealias ValueHandle = MockValueHandle
  typealias OwnedValueHandle = MockOwnedValueHandle
  typealias ClassHandle = MockClassHandle
  typealias Engine = MockEngine
  typealias RuntimeHandle = MockRuntimeHandle
  typealias ContextHandle = MockContextHandle
  typealias PropertyStringKeyHandle = MockStringHandle
  typealias PreparedScriptHandle = MockStringHandle

  static let capabilities = JSEngineCapabilities(supportsHostObjects: true)

  private static func string(from key: StaticString) -> String {
    key.withUTF8Buffer { buffer in
      String(decoding: buffer, as: UTF8.self)
    }
  }

  static func makeRuntime() -> MockRuntime {
    MockRuntime(id: "runtime")
  }

  static func makeContext(in runtime: MockRuntime) -> MockContext {
    MockContext(runtimeID: runtime.id, identity: UUID().uuidString)
  }

  static func evaluateScript(
    _ script: String,
    in context: MockContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<MockValue> {
    if script == "throw" {
      return .exception(MockValue(kind: "exception", payload: "\(context.runtimeID):throw"))
    }
    return .value(MockValue(kind: "script", payload: "\(context.runtimeID):\(script)"))
  }

  static func makeString(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "string", payload: "\(context.runtimeID):\(value)")
  }

  static func makeSymbol(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "symbol", payload: "\(context.runtimeID):\(value)")
  }

  static func makeNumber(_ value: Double, in context: MockContext) -> MockValue {
    MockValue(kind: "number", payload: "\(context.runtimeID):\(value)")
  }

  static func makeBoolean(_ value: Bool, in context: MockContext) -> MockValue {
    MockValue(kind: "boolean", payload: "\(context.runtimeID):\(value)")
  }

  static func makeNull(in context: MockContext) -> MockValue {
    MockValue(kind: "null", payload: context.runtimeID)
  }

  static func makeUndefined(in context: MockContext) -> MockValue {
    MockValue(kind: "undefined", payload: context.runtimeID)
  }

  static func makeObject(in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "object", payload: context.runtimeID))
  }

  static func makeArray(in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "array", payload: context.runtimeID))
  }

  static func propertyNames(on object: MockValue, in context: MockContext) -> [String] {
    [context.runtimeID, object.kind, object.payload]
  }

  static func getProperty(_ key: StaticString, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    getProperty(string(from: key), on: object, in: context)
  }

  static func getProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key)"))
  }

  static func getProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(
      MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key.payload)"))
  }

  static func getProperty(at index: UInt32, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "index", payload: "\(context.runtimeID):\(object.payload):\(index)"))
  }

  static func hasProperty(_ key: StaticString, on object: MockValue, in context: MockContext)
    -> Bool
  {
    hasProperty(string(from: key), on: object, in: context)
  }

  static func hasProperty(_ key: String, on object: MockValue, in context: MockContext) -> Bool {
    object.payload.contains(key)
  }

  static func hasProperty(_ key: MockValue, on object: MockValue, in context: MockContext) -> Bool {
    object.payload.contains(key.payload)
  }

  static func deleteProperty(_ key: StaticString, on object: MockValue, in context: MockContext)
    -> JSResult<Void>
  {
    deleteProperty(string(from: key), on: object, in: context)
  }

  static func deleteProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSResult<Void>
  {
    .value(())
  }

  static func deleteProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSResult<Void>
  {
    .value(())
  }

  static func callFunction(
    _ function: MockValue,
    this thisValue: MockValue?,
    arguments: [MockValue],
    in context: MockContext
  ) -> JSResult<MockValue> {
    .value(
      MockValue(
        kind: "call", payload: "\(context.runtimeID):\(function.payload):\(arguments.count)"))
  }

  static func construct(_ constructor: MockValue, arguments: [MockValue], in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "construct", payload: "\(context.runtimeID):\(arguments.count)"))
  }

  static func toObject(_ value: MockValue, in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "object", payload: value.payload))
  }

  static func isArray(_ value: MockValue, in context: MockContext) -> Bool {
    value.kind == "array"
  }

  static func isDate(_ value: MockValue, in context: MockContext) -> Bool {
    value.kind == "date"
  }

  static func isInstanceOf(_ value: MockValue, constructor: MockValue, in context: MockContext)
    -> Bool
  {
    value.payload == constructor.payload
  }

  static func looselyEquals(_ lhs: MockValue, _ rhs: MockValue, in context: MockContext) -> Bool {
    _ = context
    if lhs.kind == rhs.kind {
      return lhs.payload == rhs.payload
    }
    if lhs.kind == "number" && rhs.kind == "string" {
      return lhs.payload == rhs.payload
    }
    if lhs.kind == "string" && rhs.kind == "number" {
      return lhs.payload == rhs.payload
    }
    return false
  }

  static func strictlyEquals(
    _ lhs: MockValue,
    _ rhs: MockValue,
    in context: MockContext
  ) -> Bool {
    _ = context
    return lhs == rhs
  }

  static func setProperty(
    _ key: StaticString,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    setProperty(string(from: key), on: object, to: value, in: context, attributes: attributes)
  }

  static func setProperty(
    _ key: String,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    .value(())
  }

  static func setProperty(
    _ key: MockValue,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    .value(())
  }

  static func setProperty(
    at index: UInt32, on object: MockValue, to value: MockValue, in context: MockContext
  )
    -> JSResult<Void>
  {
    .value(())
  }

}

extension MockDriver {
  fileprivate static func resultHandle(from result: JSResult<MockValue>)
    -> JSResult<JSValueHandle<MockEngine>>
  {
    switch result {
    case .value(let value):
      return .value(JSValueHandle<MockEngine>(rawValue: value))
    case .exception(let exception):
      return .exception(JSValueHandle<MockEngine>(rawValue: exception))
    }
  }

  fileprivate static func ownedResultHandle(from result: JSResult<MockValue>)
    -> JSResult<MockOwnedValueHandle>
  {
    switch result {
    case .value(let value):
      return .value(MockOwnedValueHandle(rawValue: value))
    case .exception(let exception):
      return .exception(MockOwnedValueHandle(rawValue: exception))
    }
  }

  fileprivate static func makeRuntimeHandle() -> MockRuntimeHandle {
    MockRuntimeHandle(rawRuntime: makeRuntime())
  }

  fileprivate static func makeBorrowedContextHandleFromRuntime(
    in runtime: MockRuntimeHandle
  ) -> MockContextHandle? {
    return MockContextHandle(rawContext: makeContext(in: runtime.rawRuntime))
  }

  fileprivate static func globalObjectValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    return JSValueHandle<MockEngine>(
      rawValue: MockValue(kind: "object", payload: "\(context.rawContext.runtimeID):global"))
  }

  fileprivate static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<MockEngine>,
    in context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    _ = callback
    _ = name

    return MockOwnedValueHandle(
      rawValue: MockValue(kind: "function", payload: "\(context.rawContext.runtimeID):\(name)"))
  }

  fileprivate static func makeStringValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {

    return MockOwnedValueHandle(rawValue: makeString(value, in: context.rawContext))
  }

  fileprivate static func makeNumberValueHandle(
    _ value: Double,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {

    return MockOwnedValueHandle(rawValue: makeNumber(value, in: context.rawContext))
  }

  fileprivate static func makeSymbolValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {

    return MockOwnedValueHandle(rawValue: makeSymbol(value, in: context.rawContext))
  }

  fileprivate static func makeNullValueHandle(
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    return MockOwnedValueHandle(rawValue: makeNull(in: context.rawContext))
  }

  fileprivate static func makeUndefinedValueHandle(
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {

    return MockOwnedValueHandle(rawValue: makeUndefined(in: context.rawContext))
  }

  fileprivate static func makeObjectResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<MockOwnedValueHandle>? {

    return ownedResultHandle(from: makeObject(in: context.rawContext))
  }

  fileprivate static func makeArrayResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<MockOwnedValueHandle>? {

    return ownedResultHandle(from: makeArray(in: context.rawContext))
  }

  fileprivate static func makePreparedScriptHandle(
    _ source: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    _ = context
    return MockStringHandle(source)
  }

  fileprivate static func isPreparedScriptHandleCompatibleWithContext(
    _ script: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    _ = script
    _ = context
    return true
  }

  fileprivate static func evaluatePreparedScriptResultHandle(
    _ script: MockStringHandle,
    _ context: MockContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(
      from: evaluateScript(
        script.string,
        in: context.rawContext,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }

  fileprivate static func valueTypeForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSType? {
    _ = context
    switch value.rawValue.kind {
    case "undefined":
      return .undefined
    case "null":
      return .null
    case "boolean":
      return .boolean
    case "number":
      return .number
    case "string":
      return .string
    case "symbol":
      return .symbol
    case "object", "array", "call", "construct", "property", "index":
      return .object
    default:
      return nil
    }
  }

  fileprivate static func toBooleanForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = context
    return !value.rawValue.payload.isEmpty
  }

  fileprivate static func toNumberForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Double {
    _ = context
    return Double(value.rawValue.payload) ?? .nan
  }

  fileprivate static func toStringForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> String? {
    _ = context
    return value.rawValue.payload
  }

  fileprivate static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {

    return MockOwnedValueHandle(rawValue: makeBoolean(value, in: context.rawContext))
  }

  fileprivate static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> [String]? {

    return propertyNames(on: object.rawValue, in: context.rawContext)
  }

  fileprivate static func makePropertyStringKeyHandle(
    _ value: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    _ = context
    return MockStringHandle(value)
  }

  fileprivate static func makePropertyStringKeyHandle(
    _ value: StaticString,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    _ = context
    return value.withUTF8Buffer { buffer in
      MockStringHandle(String(decoding: buffer, as: UTF8.self))
    }
  }

  fileprivate static func makeStringValueHandle(
    fromPropertyStringKey key: MockStringHandle,
    in context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    makeStringValueHandle(key.string, context)
  }

  fileprivate static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    _ = key
    _ = context
    return true
  }

  fileprivate static func getPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: getProperty(key.string, on: object.rawValue, in: context.rawContext))
  }

  fileprivate static func setPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {

    switch setProperty(
      key.string,
      on: object.rawValue,
      to: value.rawValue,
      in: context.rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(
      from: getProperty(key.rawValue, on: object.rawValue, in: context.rawContext))
  }

  fileprivate static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: getProperty(at: index, on: object.rawValue, in: context.rawContext))
  }

  fileprivate static func setValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {

    switch setProperty(
      key.rawValue,
      on: object.rawValue,
      to: value.rawValue,
      in: context.rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {

    switch setProperty(at: index, on: object.rawValue, to: value.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func hasPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return hasProperty(key.string, on: object.rawValue, in: context.rawContext)
  }

  fileprivate static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return hasProperty(key.rawValue, on: object.rawValue, in: context.rawContext)
  }

  fileprivate static func deletePropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {

    switch deleteProperty(key.string, on: object.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func deleteValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {

    switch deleteProperty(key.rawValue, on: object.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    let rawThisValue: MockValue? = thisValue?.rawValue
    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: callFunction(
        function.rawValue,
        this: rawThisValue,
        arguments: rawArguments,
        in: context.rawContext
      )
    )
  }

  fileprivate static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: construct(constructor.rawValue, arguments: rawArguments, in: context.rawContext))
  }

  fileprivate static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: toObject(value.rawValue, in: context.rawContext))
  }

  fileprivate static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return isArray(value.rawValue, in: context.rawContext)
  }

  fileprivate static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return isDate(value.rawValue, in: context.rawContext)
  }

  fileprivate static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return isInstanceOf(value.rawValue, constructor: constructor.rawValue, in: context.rawContext)
  }

  fileprivate static func looselyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    looselyEquals(lhs.rawValue, rhs.rawValue, in: context.rawContext)
  }

  fileprivate static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    strictlyEquals(lhs.rawValue, rhs.rawValue, in: context.rawContext)
  }

  fileprivate static func makeArrayBufferWithBytesNoCopyHandle(
    in context: MockContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = bytes
    _ = byteLength
    _ = bytesDeallocator
    _ = deallocatorContext
    return nil
  }

  fileprivate static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  fileprivate static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = length
    return nil
  }

  fileprivate static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    return nil
  }

  fileprivate static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    _ = byteOffset
    _ = length
    return nil
  }

  fileprivate static func typedArrayLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayBufferForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  fileprivate static func isArrayBufferHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = value
    _ = context
    return false
  }

  fileprivate static func typedArrayKindForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSTypedArrayKind? {
    _ = value
    _ = context
    return nil
  }
}

extension MockEngine {
  public static var capabilities: JSEngineCapabilities {
    MockDriver.capabilities
  }

  public static func makeRuntimeHandle() -> MockRuntimeHandle {
    MockDriver.makeRuntimeHandle()
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: MockRuntimeHandle
  ) -> MockContextHandle? {
    MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)
  }

  public static func globalObjectValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.globalObjectValueHandle(context)
  }

  public static func contextDataStorageBox(in context: MockContextHandle)
    -> JSContextDataStorageBox?
  {
    mockContextDataStorageRegistry.withLock {
      $0[mockContextDataRegistryKey(for: context)]
    }
  }

  public static func installContextDataStorageBox(
    _ storage: JSContextDataStorageBox?,
    in context: MockContextHandle
  ) {
    mockContextDataStorageRegistry.withLock {
      $0[mockContextDataRegistryKey(for: context)] = storage
    }
  }

  @_optimize(none)
  public static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<MockEngine>,
    in context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    _ = callback
    return MockOwnedValueHandle(
      rawValue: MockValue(kind: "function", payload: "\(context.rawContext.runtimeID):\(name)"))
  }

  public static func makePreparedScriptHandle(
    _ source: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    MockDriver.makePreparedScriptHandle(source, in: context)
  }

  public static func isPreparedScriptHandleCompatibleWithContext(
    _ script: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.isPreparedScriptHandleCompatibleWithContext(script, in: context)
  }

  public static func evaluatePreparedScriptResultHandle(
    _ script: MockStringHandle,
    _ context: MockContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.evaluatePreparedScriptResultHandle(
      script,
      context,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  public static func valueTypeForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSType? {
    _ = context
    switch value.rawValue.kind {
    case "undefined":
      return .undefined
    case "null":
      return .null
    case "boolean":
      return .boolean
    case "number":
      return .number
    case "string":
      return .string
    case "symbol":
      return .symbol
    case "object", "array", "call", "construct", "property", "index":
      return .object
    default:
      return nil
    }
  }

  public static func toBooleanForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = context
    return !value.rawValue.payload.isEmpty
  }

  public static func toNumberForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Double {
    _ = context
    return Double(value.rawValue.payload) ?? .nan
  }

  public static func toStringForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> String? {
    _ = context
    return value.rawValue.payload
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    MockDriver.makeStringValueHandle(value, context)
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    MockDriver.makeSymbolValueHandle(value, context)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    MockDriver.makeNumberValueHandle(value, context)
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {

    return MockOwnedValueHandle(
      rawValue: MockDriver.makeBoolean(value, in: context.rawContext))
  }

  public static func makeNullValueHandle(
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    MockDriver.makeNullValueHandle(context)
  }

  public static func makeUndefinedValueHandle(
    _ context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    MockDriver.makeUndefinedValueHandle(context)
  }

  public static func makeObjectResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<MockOwnedValueHandle>? {
    MockDriver.makeObjectResultHandle(context)
  }

  public static func makeArrayResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<MockOwnedValueHandle>? {
    MockDriver.makeArrayResultHandle(context)
  }

  public static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> [String]? {
    MockDriver.propertyNamesForHandle(on: object, in: context)
  }

  public static func makePropertyStringKeyHandle(
    _ value: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    MockDriver.makePropertyStringKeyHandle(value, in: context)
  }

  public static func makePropertyStringKeyHandle(
    _ value: StaticString,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    MockDriver.makePropertyStringKeyHandle(value, in: context)
  }

  public static func makeStringValueHandle(
    fromPropertyStringKey key: MockStringHandle,
    in context: MockContextHandle
  ) -> MockOwnedValueHandle? {
    MockDriver.makeStringValueHandle(fromPropertyStringKey: key, in: context)
  }

  public static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.isPropertyStringKeyHandleCompatibleWithContext(key, in: context)
  }

  public static func getPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getPropertyStringKeyHandle(key, on: object, in: context)
  }

  public static func setPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    MockDriver.setPropertyStringKeyHandle(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    )
  }

  public static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getValuePropertyHandle(key, on: object, in: context)
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getIndexPropertyHandle(at: index, on: object, in: context)
  }

  public static func setValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    MockDriver.setValuePropertyHandle(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    )
  }

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.setIndexPropertyHandle(at: index, on: object, to: value, in: context)
  }

  public static func hasPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.hasPropertyStringKeyHandle(key, on: object, in: context)
  }

  public static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.hasValuePropertyHandle(key, on: object, in: context)
  }

  public static func deletePropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.deletePropertyStringKeyHandle(key, on: object, in: context)
  }

  public static func deleteValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.deleteValuePropertyHandle(key, on: object, in: context)
  }

  public static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.callFunctionHandle(
      function, this: thisValue, arguments: arguments, in: context)
  }

  public static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.constructHandle(constructor, arguments: arguments, in: context)
  }

  public static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.toObjectHandle(value, in: context)
  }

  public static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isArrayHandle(value, in: context)
  }

  public static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isDateHandle(value, in: context)
  }

  public static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isInstanceOfHandle(value, constructor: constructor, in: context)
  }

  public static func looselyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.looselyEqualsHandle(lhs, rhs, in: context)
  }

  public static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.strictlyEqualsHandle(lhs, rhs, in: context)
  }

  public static func makeArrayBufferWithBytesNoCopyHandle(
    in context: MockContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = bytes
    _ = byteLength
    _ = bytesDeallocator
    _ = deallocatorContext
    return nil
  }

  public static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  public static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = length
    return nil
  }

  public static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    return nil
  }

  public static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    _ = byteOffset
    _ = length
    return nil
  }

  public static func typedArrayLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayBufferForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  public static func isArrayBufferHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = value
    _ = context
    return false
  }

  public static func typedArrayKindForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSTypedArrayKind? {
    _ = value
    _ = context
    return nil
  }
}

@Test func engineCapabilitiesDefaultsToDisabled() {
  let capabilities = JSEngineCapabilities()

  #expect(!capabilities.supportsBigInt)
  #expect(!capabilities.supportsSymbol)
  #expect(!capabilities.supportsExternalArrayBuffer)
  #expect(!capabilities.supportsHostObjects)
  #expect(!capabilities.supportsESModules)
  #expect(!capabilities.supportsPromiseJobQueueControl)
}

@Test func hostModuleDescriptorKeepsTypeMetadata() {
  let descriptor = JSHostModuleDescriptor(
    name: "Console",
    functions: [
      JSHostFunctionDescriptor(name: "log", binding: "console_log")
    ],
    constants: [
      JSHostConstantDescriptor(name: "version", value: "1.0.0")
    ],
    types: [
      JSHostTypeDescriptor(
        name: "Timer",
        constructor: JSHostConstructorDescriptor(binding: "timer_ctor"),
        methods: [JSHostFunctionDescriptor(name: "start", binding: "timer_start")],
        staticMethods: [JSHostFunctionDescriptor(name: "now", binding: "timer_now")],
        properties: [
          JSHostPropertyDescriptor(
            name: "running",
            getterBinding: "timer_get_running",
            setterBinding: "timer_set_running"
          )
        ],
        parent: "EventTarget",
        storagePolicy: .swiftRetainedObject,
        initializerBinding: "timer_initialize",
        finalizerBinding: "timer_finalize",
        dynamicPropertyGetterBinding: "timer_dynamic_get",
        propertyEnumeratorBinding: "timer_dynamic_enumerate",
        callAsFunctionBinding: "timer_call"
      )
    ]
  )

  #expect(descriptor.name == "Console")
  #expect(descriptor.functions.count == 1)
  #expect(descriptor.constants.count == 1)
  #expect(descriptor.types.count == 1)
  #expect(descriptor.types[0].parent == "EventTarget")
  #expect(descriptor.types[0].methods[0].binding == "timer_start")
  #expect(descriptor.types[0].initializerBinding == "timer_initialize")
  #expect(descriptor.types[0].dynamicPropertyGetterBinding == "timer_dynamic_get")
  #expect(descriptor.types[0].propertyEnumeratorBinding == "timer_dynamic_enumerate")
  #expect(descriptor.types[0].callAsFunctionBinding == "timer_call")
}

@Test func genericHandlesKeepRawStorageAndEngineTyping() {
  let runtime = MockRuntimeHandle(rawRuntime: MockRuntime(id: "runtime-token"))
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "runtime-token"))
  let value = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "value-token"))

  let runtimeToken = runtime.rawRuntime
  let contextToken = context.rawContext
  let valueToken = value.rawValue
  let runtimeIsMock = runtime.engineType == MockEngine.self
  let contextIsMock = context.engineType == MockEngine.self
  let valueIsMock = value.engineType == MockEngine.self

  #expect(runtimeToken == MockRuntime(id: "runtime-token"))
  #expect(contextToken == MockContext(runtimeID: "runtime-token"))
  #expect(valueToken == MockValue(kind: "string", payload: "value-token"))
  #expect(runtimeIsMock)
  #expect(contextIsMock)
  #expect(valueIsMock)
}

@Test func engineValuePreservesHandleAndEngineType() {
  let handle = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "mock-value"))
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "test"))
  let value = JSValue<MockEngine>(handleValue: handle, in: context)

  let storedHandle = value.borrowHandle()

  // 直接存储等价性:原 storage-words round-trip(word0..word2 +
  // fromStorageWords 解出 (handle, context) 对)改写后,handle 与 context
  // 都按原身份往返。
  #expect(storedHandle == handle)
  #expect(storedHandle.rawValue == MockValue(kind: "string", payload: "mock-value"))
  #expect(storedHandle.engineType == MockEngine.self)
  #expect(value.contextHandle == context)
}

@Test func engineValueKeepsOpaquePayloadIdentity() {
  let payload = MockValue(kind: "number", payload: "runtime:7")
  let handle = JSValueHandle<MockEngine>(rawValue: payload)
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "test"))
  let value = JSValue<MockEngine>(handleValue: handle, in: context)

  let roundtrip = value.borrowHandle().rawValue

  #expect(roundtrip == payload)
  #expect(value.borrowHandle() == handle)
  #expect(value.contextHandle == context)
}

@Test func engineValueShellKeepsHandleAndEngineTyping() {
  let handle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "moved-jsvalue"))
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "test"))
  let value = JSValue<MockEngine>(handleValue: handle, in: context)

  let roundtripHandle = value.borrowHandle()
  #expect(roundtripHandle.rawValue == MockValue(kind: "string", payload: "moved-jsvalue"))
  #expect(roundtripHandle.engineType == MockEngine.self)
  #expect(roundtripHandle == handle)
  #expect(value.contextHandle == context)
}

@Test func genericResultHandleWrapsValueAndExceptionStates() {
  let valueHandle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "mock-value")
  )
  let exceptionHandle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "exception", payload: "mock-error")
  )

  let valueResult = JSResult<JSValueHandle<MockEngine>>.value(valueHandle)
  let exceptionResult = JSResult<JSValueHandle<MockEngine>>.exception(exceptionHandle)

  let valueIsException = valueResult.isException
  let exceptionIsException = exceptionResult.isException

  #expect(!valueIsException)
  #expect(exceptionIsException)

  switch consume valueResult {
  case .value(let wrapped):
    #expect(wrapped.rawValue == MockValue(kind: "string", payload: "mock-value"))
  case .exception:
    Issue.record("Expected value result case")
  }

  switch consume exceptionResult {
  case .value:
    Issue.record("Expected exception result case")
  case .exception(let wrapped):
    #expect(wrapped.rawValue == MockValue(kind: "exception", payload: "mock-error"))
  }
}

@Test func genericHandlesBridgeThroughDriverProtocol() {
  let runtime = MockDriver.makeRuntimeHandle()
  let context = MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)

  guard let context else {
    Issue.record("Expected context handle from driver")
    return
  }

  let stringValue = MockDriver.makeStringValueHandle("hello", context)
  let symbolValue = MockDriver.makeSymbolValueHandle("token", context)
  let numberValue = MockDriver.makeNumberValueHandle(42, context)
  let script = MockDriver.makePreparedScriptHandle("1 + 2", in: context)
  let throwingScript = MockDriver.makePreparedScriptHandle("throw", in: context)
  let evalValue = script.map { MockDriver.evaluatePreparedScriptResultHandle($0, context) } ?? nil
  let evalException =
    throwingScript.map { MockDriver.evaluatePreparedScriptResultHandle($0, context) } ?? nil

  guard
    let stringValue, let symbolValue, let numberValue, let script, let throwingScript,
    let evalValue,
    let evalException
  else {
    Issue.record("Expected driver bridge operations to produce handles")
    return
  }
  defer {
    _ = script.releaseReference()
    _ = throwingScript.releaseReference()
  }

  let names = MockDriver.propertyNamesForHandle(on: stringValue.borrowed(), in: context)
  let messageKey = MockDriver.makePropertyStringKeyHandle("message", in: context)
  guard let messageKey else {
    Issue.record("Expected property string key handle")
    return
  }
  defer { _ = messageKey.releaseReference() }
  let property = MockDriver.getPropertyStringKeyHandle(
    messageKey, on: stringValue.borrowed(), in: context)
  let propertySet = MockDriver.setPropertyStringKeyHandle(
    messageKey,
    on: stringValue.borrowed(),
    to: numberValue.borrowed(),
    in: context,
    attributes: [.readOnly]
  )

  #expect(propertySet)
  #expect(names == ["runtime", "string", "runtime:hello"])
  #expect(
    symbolValue.rawValue
      == MockValue(kind: "symbol", payload: "runtime:token"))

  switch consume evalValue {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "script", payload: "runtime:1 + 2"))
  case .exception:
    Issue.record("Expected script evaluation to succeed")
  }

  switch consume evalException {
  case .value:
    Issue.record("Expected script evaluation to surface exception result")
  case .exception(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "exception", payload: "runtime:throw"))
  }

  guard let property else {
    Issue.record("Expected property handle result")
    return
  }

  switch consume property {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "property", payload: "runtime:runtime:hello:message"))
  case .exception:
    Issue.record("Expected property access to succeed")
  }
}

@Test func genericHandlesBridgeObjectsCallsAndTypeHelpers() {
  let runtime = MockDriver.makeRuntimeHandle()
  let context = MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)

  guard let context else {
    Issue.record("Expected context handle from driver")
    return
  }

  let object = MockDriver.makeObjectResultHandle(context)
  let array = MockDriver.makeArrayResultHandle(context)
  let function = MockDriver.makeStringValueHandle("callable", context)
  let argument = MockDriver.makeNumberValueHandle(7, context)
  let primitive = MockDriver.makeStringValueHandle("boxed", context)
  let constructor = MockDriver.makeStringValueHandle("boxed", context)
  let nullValue = MockDriver.makeNullValueHandle(context)
  let undefinedValue = MockDriver.makeUndefinedValueHandle(context)

  guard let object, let array, let function, let argument, let primitive, let constructor,
    let nullValue, let undefinedValue
  else {
    Issue.record("Expected object/array/call scaffolding handles")
    return
  }

  let callResult = MockDriver.callFunctionHandle(
    function.borrowed(), arguments: [argument.borrowed()], in: context)
  let constructResult = MockDriver.constructHandle(
    function.borrowed(), arguments: [argument.borrowed()], in: context)
  let boxedResult = MockDriver.toObjectHandle(primitive.borrowed(), in: context)
  let isArray = MockDriver.isArrayHandle(function.borrowed(), in: context)
  let isDate = MockDriver.isDateHandle(function.borrowed(), in: context)
  let isInstanceOf = MockDriver.isInstanceOfHandle(
    primitive.borrowed(), constructor: constructor.borrowed(), in: context)

  switch consume object {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "object", payload: "runtime"))
  case .exception:
    Issue.record("Expected object creation to succeed")
  }

  switch consume array {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "array", payload: "runtime"))
  case .exception:
    Issue.record("Expected array creation to succeed")
  }

  switch consume callResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "call", payload: "runtime:runtime:callable:1"))
  default:
    Issue.record("Expected function call to succeed")
  }

  switch consume constructResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "construct", payload: "runtime:1"))
  default:
    Issue.record("Expected constructor call to succeed")
  }

  switch consume boxedResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "object", payload: "runtime:boxed"))
  default:
    Issue.record("Expected toObject bridge to succeed")
  }

  #expect(isArray == false)
  #expect(isDate == false)
  #expect(isInstanceOf == true)
  #expect(nullValue.rawValue == MockValue(kind: "null", payload: "runtime"))
  #expect(
    undefinedValue.rawValue
      == MockValue(kind: "undefined", payload: "runtime"))
}

@Test func genericValueEqualityUsesDriverHooks() async {
  let context = JSContext<MockEngine>()

  await context.withInstantContext { context in
    let oneNumber = JSValue<MockEngine>(number: 1, in: context)
    let oneString = JSValue<MockEngine>(string: "1.0", in: context)
    let oneNumberCopy = JSValue<MockEngine>(number: 1, in: context)
    let twoNumber = JSValue<MockEngine>(number: 2, in: context)

    let looselyEqual = oneNumber.looselyEquals(oneString, in: context)
    let looselyNotEqual = !oneNumber.looselyEquals(twoNumber, in: context)
    let strictlyEqual = oneNumber.strictlyEquals(oneNumberCopy, in: context)
    let strictlyNotEqual = !oneNumber.strictlyEquals(oneString, in: context)

    #expect(looselyEqual)
    #expect(looselyNotEqual)
    #expect(strictlyEqual)
    #expect(strictlyNotEqual)
  }
}

@Test func propertyAttributesOptionSet() {
  let value: JSPropertyAttributes = [.dontDelete, .readOnly]
  #expect(value.contains(.dontDelete))
  #expect(value.contains(.readOnly))
  #expect(!value.contains(.dontEnum))
  #expect(JSPropertyAttributes.none.rawValue == 0)
}

@Test func classAttributesOptionSet() {
  let value: JSClassAttributes = [.noAutomaticPrototype]
  #expect(value.contains(.noAutomaticPrototype))
  #expect(JSClassAttributes.none.rawValue == 0)
}
// MARK: - Arena tracking for MockEngine

private let contextReleaseLog = Mutex<[String: [MockValueHandle]]>([:])

private func releaseLog(for identity: String) -> [MockValueHandle] {
  contextReleaseLog.withLock { $0[identity] ?? [] }
}

private func clearReleaseLog(for identity: String) {
  contextReleaseLog.withLock { $0[identity] = nil }
}
