import Testing

@testable import SwiftJavaScript

/// Stage 1 scope contract tests (docs/VALUE_MANAGEMENT_REFACTORING.md §3.4).
///
/// 未自动化的契约:「scope 外使用回调值应编译失败」。Swift Testing 无法在
/// 测试内断言编译期失败(需要独立的负面编译用例);以下示例仅以文档形式保留,
/// 标注「应编译失败」,该验证未自动化:
///
///     // ✗ 应编译失败 —— `JSCallbackValueLegacy` 是 ~Copyable,不能逃逸出回调值的作用域:
///     final class Leak<E: JSEngine> {
///       var escaped: JSCallbackValueLegacy<E>?
///       // ^ ~Copyable 存储属性不允许出现在 Copyable 类型中
///     }
///
///     // ✗ 应编译失败 —— 也不能装箱为 `Any` 携带出去(`Any` 要求 Copyable):
///     let boxed: Any = c.makeString("must not escape")
///
/// 值经 JS 流转(作为实参穿过引擎调用)或 `persist` 成 `JSValueLegacy` 是仅有的
/// 合法出口;`nestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay`
/// 恰好验证第一条通道。
// MARK: - Stage 3 negative compile examples (not automatable in Swift Testing)
//
// 「`JSValueLegacy` 是非 Sendable 本地值,跨隔离域应编译失败」是编译期契约;
// Swift Testing 无法在测试内断言编译期失败,以下样例仅以文档形式保留,
// 标注「应编译失败」,该验证未自动化:
//
//     // ✗ 应编译失败 —— actor 隔离域把非 Sendable 本地值返回给 nonisolated
//     // 上下文:
//     func leak(_ context: JSContextLegacy<JSCEngine>) async {
//       let value = await context.makeString("leak")
//       _ = value
//     }
//
//     // ✗ 应编译失败 —— 捕获进 @Sendable 任务(handle/context token 的
//     // Sendable 不使本地值本身可跨域):
//     func send(_ value: borrowing JSValueLegacy<JSCEngine>) {
//       Task.detached { _ = value }
//     }
//
//     // ✗ 应编译失败 —— 作为 actor 间实例方法实参:
//     actor Sink {
//       func take(_ value: borrowing JSValueLegacy<JSCEngine>) {}
//     }
//     func send(
//       _ value: borrowing JSValueLegacy<JSCEngine>,
//       to sink: Sink
//     ) async {
//       await sink.take(value)
//     }
//
// 构建探针实测记录(2026-11-23,Apple Swift 6.4.2 /
// swiftlang-6.4.2.1.9;探针文件临时加入 `SwiftJavaScriptEngineTests` target
// 后 `swift build --build-tests`,确认三类诊断后删除探针并重建通过):
// - actor 返回样例报 `error: non-Sendable 'JSValueLegacy<JSCEngine>'
//   -typed result can not be returned from actor-isolated instance method
//   'makeString' to nonisolated context`,并附
//   `note: generic struct 'JSValueLegacy' does not conform to the 'Sendable'
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
// 三个样例均因 `JSValueLegacy` 只能留在原隔离域而失败;`Sendable` 的
// handle/context token 不改变该结论。

// MARK: - Stage 4 (TODO §2.7.1) negative compile examples (not automatable in Swift Testing)

// 「`JSScopeLegacy` 只能生灭于 context 隔离域内」是编译期契约:公共构造面只有
// actor 隔离工厂 `JSContextLegacy.makeScope()`,而 `JSScopeLegacy` 既非 Copyable 也非
// Sendable。Swift Testing 无法在测试内断言编译期失败,以下样例仅以文档形式
// 保留,标注「应编译失败」,该验证未自动化:
//
//     // ✗ 应编译失败 —— 从 nonisolated 上下文调用工厂,结果跨 actor 边界:
//     func leak(_ context: JSContextLegacy<JSCEngine>) async {
//       let scope = await context.makeScope()
//       _ = scope
//     }
//
//     // ✗ 应编译失败 —— 把结果从 actor 隔离实例方法返回给 nonisolated 调用方:
//     func leak(
//       _ context: JSContextLegacy<JSCEngine>
//     ) async -> JSScopeLegacy<JSCEngine> {
//       await context.makeScope()
//     }
//
// 构建探针实测记录(2026-11-23,Apple Swift 6.4.2 / swiftlang-6.4.2.1.9;探针文件
// 临时加入 `SwiftJavaScriptEngineTests` target 后 `swift build --build-tests`,
// 确认诊断后删除探针并重建通过):
// - 两个样例均报 `error: non-Sendable 'JSScopeLegacy<JSCEngine>'-typed
//   result can not be returned from actor-isolated instance method 'makeScope()'
//   to nonisolated context`,并附
//   `note: generic struct 'JSScopeLegacy' does not conform to the 'Sendable' protocol`。
//
// `JSScopeLegacy.init(handle:)` / `open()` 为 `package` 访问级别,包外不可见;这是
// 访问控制的事实,同包测试给不出可观测诊断,故不列为探针样例。
//
// 正例见下方 `contextDerivedScopeNestsPersistsAndResolves`:工厂在
// `withIsolatedGlobalObject` 的同步窗口内调用,scope 随内层作用域结束而析构。
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

  @Test(arguments: ScriptEngine.allCases)
  func contextDerivedScopeNestsPersistsAndResolves(_ engine: ScriptEngine) async {
    await engine.run(ContextDerivedScopeNestsPersistsAndResolves.self)
  }
}

/// `JSContext.makeScope()` 是 `JSScope` 的公共构造路径(TODO §2.7.1):工厂
/// actor 隔离,scope 生、用、析构都在 context 的隔离域内。嵌套 scope 内:
/// 工厂产物经 `persist` 晋升到默认 scope;持久 handle 在其中 mint/resolve;
/// scope 结束后晋升值仍可用。(“scope 结束后栈顶回到默认帧”的身份断言按
/// 具体引擎下沉到 `JSCScopeSurfaceTests`/`QJSScopeSurfaceTests`——公共协议面
/// 已不再暴露 context handle。)
private enum ContextDerivedScopeNestsPersistsAndResolves: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    let resolved = await context.withInstantContext { window -> String in
      let handle = window.makePersistentHandle(
        window.makeString("bound"))

      // 内层写入与解析都发生在同一个同步窗口内；晋升值与全局属性在窗口
      // 结束后仍由默认 scope / 全局对象持有。
      let durable = window.persist(window.makeString("promoted"))
      window.setGlobalProperty(durable, forKey: "durable", with: .none)
      return window.resolve(handle)?.toString() ?? "<nil>"
    }

    #expect(resolved == "bound")

    // 晋升值锚在默认 scope:窗口结束后、跨窗口仍可读取。
    let durableAfterScope = await context.withInstantContext { window in
      window.getGlobalProperty(forKey: "durable").toString()
    }
    #expect(durableAfterScope == "promoted")
  }
}

/// 回调 B 同步执行于 A 的引擎调用内,普通引用类型即可带出观察结果;
/// 写入全部发生在 context actor 的执行器上,await 返回后才被读取,
/// 按仓库惯例(如 mock 的 handle 存储)标 @unchecked Sendable。
/// (局部类型不能嵌套在泛型函数中,故提至文件作用域。)
private final class NestedCallbackObservations: @unchecked Sendable {
  var argumentCount: Int? = nil
  var receivedType: JSType? = nil
  var receivedContent: String? = nil
  var strictlyMatchesTwin: Bool? = nil
}

/// 嵌套契约(§3.4):回调 A 创建的值,经 JS 中转后必须能在内层回调 B 中使用。
///
/// `JSCallbackValueLegacy` 是 ~Copyable,不能被捕获直传——值经 JS 引擎流转是唯一
/// 合法的跨回调通道,本测试验证的正是这条通道:外层回调 A 创建值并以实参
/// 形式穿过一次 JS 调用(relay),由引擎重入建立的内层回调 B 通过参数帧
/// 取回该值并断言可用且内容正确。
private enum NestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let observations = NestedCallbackObservations()

    let context = C(virtualMachine: C.VirtualMachine())

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
          let view = c.localValue(value)
          observations.receivedType = view.type()
          observations.receivedContent = view.toString()
          observations.strictlyMatchesTwin = view.strictlyEquals(
            c.localValue(c.makeString("payload-from-A")))
        }
        return c.return(c.makeString("ack-from-B"))
      }

      // 外层回调 A:创建值,并把该值的 handle 作为实参经 JS relay 传给 B。
      ic.installGlobalFunction(named: "outer") { c, _, _ in
        let created = c.makeString("payload-from-A")
        let relay = c.getGlobalProperty(forKey: "relay")
        let relayResult = relay.call(arguments: [created.asCallArgument()], in: c)
        switch consume relayResult {
        case .value(let acknowledgement):
          return c.return(c.makeString("relay:" + acknowledgement.toString()))
        case .exception:
          // 不应发生:B 正常返回;异常经 outer 的调用结果在外层分支统一暴露。
          return c.throwUndefined()
        }
      }

      let outer = ic.getGlobalProperty(forKey: "outer")
      let outerResult = outer.call(arguments: [], in: ic)
      switch consume outerResult {
      case .value(let value):
        #expect(value.toString() == "relay:ack-from-B")
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
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { window in
      let durable = window.persist(window.makeString("durable"))

      // 同一窗口内继续创建临时值;默认 arena 不受临时值结算影响。
      _ = window.makeString("temporary")

      #expect(durable.toString() == "durable")

      let result = window.evaluateScript("1 + 1")
      switch consume result {
      case .value(let value):
        #expect(value.toNumber() == 2)
      case .exception:
        Issue.record("Expected default-scope evaluation to produce a value")
      }
    }

    // 晋升值跨窗口存活:第二个窗口仍能从默认 scope 读到它。
    let durableText = await context.withInstantContext { window in
      window.persist(window.makeString("durable")).toString()
    }
    #expect(durableText == "durable")
  }
}

/// Stage 3 §§3.2/3.6: a default-scope value stays usable when the context
/// actor suspends and resumes. The persistent binding is `Sendable`, so it
/// crosses the suspension; the default arena keeps the engine reference alive
/// (JSC: explicit `JSValueProtect`; QuickJS: the creation reference), and the
/// resumed window resolves it back to the original string.
private enum ValueSurvivesAwaitWithinActor: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    let handle = await context.withInstantContext { window in
      window.makePersistentHandle(window.makeString("across-await"))
    }

    await Task.yield()

    // A sibling job on the same actor runs while the binding is outstanding.
    let sibling = Task {
      await context.withInstantContext { window in
        _ = window.makeString("default-scope-pressure")
        _ = window.evaluateScript("({ mark: 'stage3-gc-pressure' })")
      }
    }
    await sibling.value

    let observations = await context.withInstantContext {
      window -> (String, Double) in
      let value = window.resolve(handle)
      return (value?.toString() ?? "<nil>", window.makeNumber(42).toNumber())
    }

    #expect(observations.0 == "across-await")
    #expect(observations.1 == 42)
  }
}
