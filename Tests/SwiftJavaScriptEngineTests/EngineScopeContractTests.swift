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
@Suite
struct EngineScopeContractTests {
  @Test(arguments: ScriptEngine.allCases)
  func nestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay(_ engine: ScriptEngine) async {
    await engine.run(NestedCallbackUsesValueCreatedByOuterCallbackViaJSRelay.self)
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
