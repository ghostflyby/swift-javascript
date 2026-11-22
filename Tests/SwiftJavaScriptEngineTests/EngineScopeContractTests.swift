import Testing

@testable import SwiftJavaScript

/// Stage 1 scope contract tests (docs/VALUE_MANAGEMENT_REFACTORING.md §3.4).
///
/// 未自动化的契约:「scope 外使用回调值应编译失败」。Swift Testing 无法在
/// 测试内断言编译期失败(需要独立的负面编译用例);以下示例仅以文档形式保留,
/// 标注「应编译失败」,该验证未自动化:
///
///     // ✗ 应编译失败 —— `JSCallbackValue` 是 ~Copyable,不能逃逸出回调值的作用域:
///     final class Leak<E: JSEngine> {
///       var escaped: JSCallbackValue<E>?
///       // ^ ~Copyable 存储属性不允许出现在 Copyable 类型中
///     }
///
///     // ✗ 应编译失败 —— 也不能装箱为 `Any` 携带出去(`Any` 要求 Copyable):
///     let boxed: Any = c.makeString("must not escape")
///
/// 值经 JS 流转(作为实参穿过引擎调用)或 `persist` 成 `JSValue` 是仅有的
/// 合法出口;`nestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay`
/// 恰好验证第一条通道。
// MARK: - Stage 3 negative compile examples (not automatable in Swift Testing)
//
// 「`JSValue` 是非 Sendable 本地值,跨隔离域应编译失败」是编译期契约;
// Swift Testing 无法在测试内断言编译期失败,以下样例仅以文档形式保留,
// 标注「应编译失败」,该验证未自动化:
//
//     // ✗ 应编译失败 —— actor 隔离域把非 Sendable 本地值返回给 nonisolated
//     // 上下文:
//     func leak(_ context: JSContext<JavaScriptCoreEngine>) async {
//       let value = await context.makeString("leak")
//       _ = value
//     }
//
//     // ✗ 应编译失败 —— 捕获进 @Sendable 任务(handle/context token 的
//     // Sendable 不使本地值本身可跨域):
//     func send(_ value: borrowing JSValue<JavaScriptCoreEngine>) {
//       Task.detached { _ = value }
//     }
//
//     // ✗ 应编译失败 —— 作为 actor 间实例方法实参:
//     actor Sink {
//       func take(_ value: borrowing JSValue<JavaScriptCoreEngine>) {}
//     }
//     func send(
//       _ value: borrowing JSValue<JavaScriptCoreEngine>,
//       to sink: Sink
//     ) async {
//       await sink.take(value)
//     }
//
// 构建探针实测记录(2026-11-23,Apple Swift 6.4.2 /
// swiftlang-6.4.2.1.9;探针文件临时加入 `SwiftJavaScriptEngineTests` target
// 后 `swift build --build-tests`,确认三类诊断后删除探针并重建通过):
// - actor 返回样例报 `error: non-Sendable 'JSValue<JavaScriptCoreEngine>'
//   -typed result can not be returned from actor-isolated instance method
//   'makeString' to nonisolated context`,并附
//   `note: generic struct 'JSValue' does not conform to the 'Sendable'
//   protocol`;
// - @Sendable 捕获样例报 `error: passing closure as a 'sending' parameter
//   risks causing data races between code in the current isolation context
//   and concurrent execution of the closure`(附
//   `note: closure captures 'value' which is accessible to code in the
//   current isolation context`),以及参数声明处的
//   `error: 'value' cannot be captured by an escaping closure since it is a
//   borrowed parameter`;
// - actor 间实参样例报 `error: sending 'value' risks causing data races`
//   (附 `note: sending 'value' to actor-isolated instance method 'take'
//   risks causing data races between actor-isolated code and code in the
//   current isolation context`)。
//
// 三个样例均因 `JSValue` 只能留在原隔离域而失败;`Sendable` 的
// handle/context token 不改变该结论。
@Suite
struct EngineScopeContractTests {
  @Test(arguments: ScriptEngine.allCases)
  func nestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay(_ engine: ScriptEngine) async {
    await engine.run(NestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func defaultScopeValueSurvivesNestedInstantScope(_ engine: ScriptEngine) async {
    await engine.run(DefaultScopeValueSurvivesNestedInstantScope.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func localValueSurvivesAwaitWithinActor(_ engine: ScriptEngine) async {
    await engine.run(ValueSurvivesAwaitWithinActor.self)
  }
}

/// 回调 B 同步执行于 A 的引擎调用内,普通引用类型即可带出观察结果;
/// 写入全部发生在 context actor 的执行器上,await 返回后才被读取,
/// 按仓库惯例(如 MockValueHandleStorage)标 @unchecked Sendable。
/// (局部类型不能嵌套在泛型函数中,故提至文件作用域。)
private final class NestedCallbackObservations: @unchecked Sendable {
  var argumentCount: Int? = nil
  var receivedType: JSType? = nil
  var receivedContent: String? = nil
  var strictlyMatchesTwin: Bool? = nil
}

/// 嵌套契约(§3.4):回调 A 创建的值,经 JS 中转后必须能在内层回调 B 中使用。
///
/// `JSCallbackValue` 是 ~Copyable,不能被捕获直传——值经 JS 引擎流转是唯一
/// 合法的跨回调通道,本测试验证的正是这条通道:外层回调 A 创建值并以实参
/// 形式穿过一次 JS 调用(relay),由引擎重入建立的内层回调 B 通过参数帧
/// 取回该值并断言可用且内容正确。
private enum NestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let observations = NestedCallbackObservations()

    let context = JSContext<E>()

    await context.withInstantContext { ic in
      // JS 中转层:relay 把收到的实参原样转发给 native inner。
      switch ic.evaluateScript("globalThis.relay = (v) => inner(v)") {
      case .value:
        break
      case .exception:
        Issue.record("Expected relay installation to succeed")
      }

      // 内层回调 B:scope 由引擎 trampoline 建立,与 A 的 scope 同 context 嵌套。
      // A 的 arena 未关,其创建的值在 B 中必须可用且内容正确。
      ic.installGlobalFunction(named: "inner") { c, _, arguments in
        observations.argumentCount = arguments.count
        arguments.withValue(at: 0, in: c) { value in
          observations.receivedType = value.type()
          observations.receivedContent = value.toString()
          observations.strictlyMatchesTwin = value.strictlyEquals(c.makeString("payload-from-A"))
        }
        return c.return(c.makeString("ack-from-B"))
      }

      // 外层回调 A:创建值,并把该值的 handle 作为实参经 JS relay 传给 B。
      ic.installGlobalFunction(named: "outer") { c, _, _ in
        let created = c.makeString("payload-from-A")
        let relay = c.getGlobalProperty(forKey: "relay")
        let relayResult = c.call(function: relay, arguments: [created.handle])
        switch consume relayResult {
        case .value(let acknowledgement):
          return c.return(c.makeString("relay:" + acknowledgement.toString(in: c)))
        case .exception:
          // 不应发生:B 正常返回;异常经 outer 的调用结果在外层分支统一暴露。
          return c.throwUndefined()
        }
      }

      let outer = ic.getGlobalProperty(forKey: "outer")
      let outerResult = outer.call(in: ic)
      switch consume outerResult {
      case .value(let value):
        #expect(value.toString(in: ic) == "relay:ack-from-B")
      case .exception:
        Issue.record("Expected outer callback to complete without exception")
      }
    }

    #expect(observations.argumentCount == 1)
    #expect(observations.receivedType == .string)
    #expect(observations.receivedContent == "payload-from-A")
    #expect(observations.strictlyMatchesTwin == true)
  }
}

/// Stage 3 §3.6:actor 值工厂产物落在 context 默认 scope。显式(同步)scope
/// 在默认帧之上打开又关闭,默认 arena 的值仍可用;由 `evaluateScript`
/// 产生的值同样由默认 scope 承接(而非临时 scope 的 drain)。
private enum DefaultScopeValueSurvivesNestedInstantScope: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withIsolatedGlobalObject { context, _ in
      let durable = context.makeString("durable")

      // 同步 scope 在默认帧之上压入/弹出,不触碰默认 arena。
      context.withInstantContext { instantContext in
        _ = instantContext.makeString("temporary")
      }

      #expect(durable.toString(in: context) == "durable")

      let result = context.evaluateScript("1 + 1")
      switch consume result {
      case .value(let value):
        #expect(value.toDouble(in: context) == 2)
      case .exception:
        Issue.record("Expected default-scope evaluation to produce a value")
      }
    }
  }
}

/// Stage 3 §§3.2/3.6: a default-scope `JSValue` stays usable when the
/// context actor suspends and resumes. The value never leaves its isolation
/// domain; the default arena keeps the engine reference alive across the
/// suspension (JSC: explicit `JSValueProtect`; QuickJS: the creation
/// reference), so the resumed read must observe the original string.
///
/// 未自动化契约(编译期,Swift Testing 无法在测试内断言):`JSValue` 是非
/// `Sendable` 本地值,把同一视图送进另一个隔离域必须编译失败。文档样例与
/// 构建探针实测记录见本文件顶部的 Stage 3 负面样例说明。
private enum ValueSurvivesAwaitWithinActor: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    let observations = await context.stage3ProbeValueAcrossAwait()

    #expect(observations.valueBeforeSuspension == "across-await")
    #expect(observations.valueAfterSuspension == "across-await")
    #expect(observations.valueAfterSiblingJobAndGC == "across-await")
    #expect(observations.numberAfterSuspension == 42)
  }
}

/// Observations are `Sendable`; the non-`Sendable` `JSValue` never leaves
/// the context actor's isolation domain (the probe is an actor-isolated
/// method, not a nonisolated helper receiving the value).
private struct Stage3AwaitObservations: Sendable {
  let valueBeforeSuspension: String
  let valueAfterSuspension: String
  let valueAfterSiblingJobAndGC: String
  let numberAfterSuspension: Double
}

extension JSContext where E: JSEngine {
  /// Runs entirely on this actor: the durable value is created, the actor
  /// suspends, other default-scope allocations and another job run on the
  /// same actor, then the value is read again. `JSValue` is never returned
  /// or captured by a nonisolated context, so this does not cross an
  /// isolation domain.
  fileprivate func stage3ProbeValueAcrossAwait() async -> Stage3AwaitObservations {
    let durable = makeString("across-await")
    let before = durable.toString(in: self)

    // First suspension: the value's frame is no longer on the synchronous
    // stack while it is outstanding.
    await Task.yield()
    let afterFirstSuspension = durable.toString(in: self)

    // Heap pressure on the default arena between suspension and use.
    for index in 0..<32 {
      _ = makeString("default-scope-pressure-\(index)")
    }
    withInstantContext { scoped in
      _ = scoped.makeString("nested-scope-temporary")
    }

    // A sibling job on the same actor runs while `durable` is outstanding;
    // it also forces a JSC collection so an unprotected value would be
    // observable as corruption here rather than waiting for incidental GC.
    let number = makeNumber(42)
    let sibling = Task { @Sendable [self] in
      await self.stage3SiblingJobAndCollection()
    }
    await sibling.value

    let numberAfter = number.toDouble(in: self)
    let afterSibling = durable.toString(in: self)

    return Stage3AwaitObservations(
      valueBeforeSuspension: before,
      valueAfterSuspension: afterFirstSuspension,
      valueAfterSiblingJobAndGC: afterSibling,
      numberAfterSuspension: numberAfter
    )
  }

  /// Same-actor sibling work: default-scope allocation plus an explicit
  /// collection on GC engines (JSC). Reference-counted engines ignore the
  /// collection hook because their creation reference is already the root.
  fileprivate func stage3SiblingJobAndCollection() async {
    for index in 0..<16 {
      _ = makeString("sibling-\(index)")
    }
    await Task.yield()
    // JSC's conservative stack scan does not see heap-resident default-scope
    // arenas, so an explicit collection in the middle of the suspension is
    // the strongest check that the explicit root is doing its job. QuickJS
    // is refcounted and needs no collection.
    stage3CollectGarbageIfSupported(driverContextHandle)
    _ = evaluateScript("({ mark: 'stage3-gc-pressure' })")
  }
}
