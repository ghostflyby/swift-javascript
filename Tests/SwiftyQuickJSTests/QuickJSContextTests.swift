import Synchronization
import Testing

@testable import SwiftJavaScript
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

@Test func quickJSValueHandleStoresHandleAndContextDirectly() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withInstantContext { context in
    let value = context.makeNumber(42)
    let handle = value.handle
    let stored = JSValue<QuickJSEngine>(handleValue: handle, in: context.driverContextHandle)
    #expect(stored.borrowHandle().ref.tag == handle.ref.tag)
    #expect(stored.borrowHandle().ref.u.int32 == handle.ref.u.int32)
    #expect(stored.contextHandle == context.driverContextHandle)
    // Both views are non-owning; the arena created by makeNumber owns the
    // reference and settles it at drain.
  }
}

@Test func quickJSHandleStorageWordsLayout() {
  #expect(MemoryLayout<CQuickJSValue>.stride == 2 * MemoryLayout<UInt64>.stride)
  #expect(MemoryLayout<CQuickJSValueUnion>.size == MemoryLayout<UInt64>.size)
}

/// Stage 3 §2.3: `persist` is a creation-reference **transfer**, not a
/// retain-and-abandon. QuickJS is reference-counted, so the accounting is
/// observable through the runtime allocator: while the target arena holds
/// the value the runtime has one more live allocation than the baseline,
/// and after the target drains the runtime returns exactly to baseline.
/// A leaked creation reference (the old +1) would keep the string and its
/// allocation alive here; a double settlement would corrupt/free it twice.
@Test func quickJSPersistTransferSettlesCreationReferenceExactlyOnce() async {
  let virtualMachine = JSVirtualMachine<QuickJSEngine>()
  var context: JSContext<QuickJSEngine>? = JSContext(virtualMachine: virtualMachine)
  let runtime = virtualMachine.driverRuntimeHandle

  var baseline = JSMemoryUsage()
  JS_ComputeMemoryUsage(runtime.ref, &baseline)

  await context!.withInstantContext { outer in
    var target = JSScope<QuickJSEngine>(handle: outer.driverContextHandle)
    target.open()

    do {
      let source = JSInstantContext<QuickJSEngine>(handle: outer.driverContextHandle)
      let created = source.makeString("stage3-persist-transfer")
      let transferred = source.persist(created, into: target)

      #expect(transferred.borrowHandle() == created.handle)
      #expect(transferred.toString(in: outer) == "stage3-persist-transfer")
    }

    // The source arena is gone. Because persist removed the element, its
    // drain released nothing: the value is still exactly one live allocation
    // in the target arena.
    var whileTargetHolds = JSMemoryUsage()
    JS_ComputeMemoryUsage(runtime.ref, &whileTargetHolds)
    #expect(whileTargetHolds.malloc_count == baseline.malloc_count + 1)
    #expect(whileTargetHolds.malloc_size > baseline.malloc_size)

    // `target` closes here.
  }

  // The single creation reference was settled by the target drain. Zero
  // leak (the old retain-and-abandon left +1) and zero double free (the
  // source had nothing left to settle).
  var afterDrain = JSMemoryUsage()
  JS_ComputeMemoryUsage(runtime.ref, &afterDrain)
  #expect(afterDrain.malloc_count == baseline.malloc_count)
  #expect(afterDrain.malloc_size == baseline.malloc_size)

  context = nil
}

/// FIFO sentinel for the persistent-handle settlement path (same shape as
/// the Mock tests' `IsolatedDeinitBarrier`, `JSEngineCoreTypesTests.swift`):
/// the stateful ping forces a real isolation hop onto the VM's dedicated
/// executor, so the await returns only after cleanup closures queued before
/// it have run. The counter is load-bearing — an empty actor method is
/// optimized into a non-hopping call.
private actor QuickJSSettlementBarrier {
  nonisolated let unownedExecutor: UnownedSerialExecutor
  private var pings = 0

  init(virtualMachine: JSVirtualMachine<QuickJSEngine>) {
    self.unownedExecutor = virtualMachine.unownedExecutor
  }

  func ping() {
    pings &+= 1
  }

  func pingCount() -> Int { pings }
}

private func awaitQuickJSSettlement(on virtualMachine: JSVirtualMachine<QuickJSEngine>) async {
  let barrier = QuickJSSettlementBarrier(virtualMachine: virtualMachine)
  await barrier.ping()
  _ = await barrier.pingCount()
}

/// Stage 4 design §8.2 case 4: a full mint/invalidate cycle returns the
/// runtime allocator to its baseline (`JS_ComputeMemoryUsage` as the proxy,
/// the Stage 3 §2.3 ledger convention). Every binding duplicates a
/// reference to a distinct engine-allocated string, so a never-settled or
/// double-settled binding is observable as a permanent allocator delta.
///
/// The first cycle is warmup: it pays one-time costs (lazy runtime
/// structures, registry slab) whose slots the measured cycle then reuses.
/// "No growth" is the exact equality of the measured cycle — the leak
/// detector is per-cycle growth, not first-touch allocation.
@Test func quickJSPersistentHandleCycleReturnsAllocatorToBaseline() async {
  let virtualMachine = JSVirtualMachine<QuickJSEngine>()
  var context: JSContext<QuickJSEngine>? = JSContext(virtualMachine: virtualMachine)
  let runtime = virtualMachine.driverRuntimeHandle
  let bindings = 1000

  func mintCycle() async -> [JSPersistentHandle<QuickJSEngine>] {
    await context!.withInstantContext { scope in
      var handles: [JSPersistentHandle<QuickJSEngine>] = []
      handles.reserveCapacity(bindings)
      for index in 0..<bindings {
        let value = scope.makeString("stage4-baseline-\(index)")
        handles.append(scope.makePersistentHandle(value))
      }
      return handles
    }
  }

  // Warmup cycle: settles back onto the free list, so the measured cycle
  // reuses its slots instead of growing the slab.
  let warmupHandles = await mintCycle()
  for handle in warmupHandles {
    #expect(handle.invalidate())
  }
  await awaitQuickJSSettlement(on: virtualMachine)

  var baseline = JSMemoryUsage()
  JS_ComputeMemoryUsage(runtime.ref, &baseline)

  // Measured cycle: 1000 engine-allocated strings kept alive only by their
  // bindings, then all invalidated and settled through the VM executor.
  let measuredHandles = await mintCycle()
  for handle in measuredHandles {
    #expect(handle.invalidate())
  }
  await awaitQuickJSSettlement(on: virtualMachine)

  var after = JSMemoryUsage()
  JS_ComputeMemoryUsage(runtime.ref, &after)
  #expect(after.malloc_count == baseline.malloc_count)
  #expect(after.malloc_size == baseline.malloc_size)

  context = nil
}

private final class QuickJSExportedNode: JSClassValueConvertible, @unchecked Sendable {
  typealias Engine = QuickJSEngine
  typealias ParentClass = JSClassParentDescriptor<QuickJSEngine, Never>
  typealias PropertyNameAccumulator = Never
  typealias ClassDefinition = QuickJSClassDefinition

  var name: String
  var count: Double

  init(name: String, count: Double) {
    self.name = name
    self.count = count
  }

  static var jsClassDefinition: QuickJSClassDefinition {
    var definition = QuickJSClassDefinition()
    definition.className = "QuickJSExportedNode"
    definition.hasProperty = { _, _, property in
      property == "name" || property == "count" || property == "label"
    }
    definition.getProperty = { context, this, property in
      guard let instance = try? Self.tryDecode(this, in: context) else {
        return .exception(
          SwiftJavaScript.JSValue<QuickJSEngine>(
            string: "failed to decode QuickJSExportedNode",
            in: context
          )
        )
      }
      switch property {
      case "name":
        return .value(SwiftJavaScript.JSValue<QuickJSEngine>(string: instance.name, in: context))
      case "count":
        return .value(SwiftJavaScript.JSValue<QuickJSEngine>(number: instance.count, in: context))
      case "label":
        return .value(
          context.makeFunction(named: "label") { c, this, arguments in
            let thisValue = JSValue<QuickJSEngine>(
              handleValue: this.handle, in: c.driverContextHandle
            )
            guard
              let instance = try? QuickJSExportedNode.tryDecode(thisValue, in: c),
              arguments.count == 1
            else {
              return JSCallbackReturn(temporary: c.makeUndefined().handle)
            }
            let prefix: String = arguments.unpack(
              types: String.self,
              in: c
            )
            return JSCallbackReturn(
              persistent: c.persist(c.makeString("\(prefix):\(instance.name):\(instance.count)")))
          }
        )
      default:
        return .value(SwiftJavaScript.JSValue<QuickJSEngine>(undefinedIn: context))
      }
    }
    definition.setProperty = { context, this, property, value in
      guard let instance = try? Self.tryDecode(this, in: context) else {
        return SwiftJavaScript.JSValue<QuickJSEngine>(
          string: "failed to decode QuickJSExportedNode",
          in: context
        )
      }
      switch property {
      case "name":
        instance.name = value.toString(in: context)
      case "count":
        instance.count = value.toDouble(in: context)
      default:
        return nil
      }
      return nil
    }
    definition.deleteProperty = { _, _, property in
      property == "name" || property == "count"
    }
    return definition
  }
}

private final class QuickJSStaticMemberNode: JSClassValueConvertible, @unchecked Sendable {
  typealias Engine = QuickJSEngine
  typealias ParentClass = JSClassParentDescriptor<QuickJSEngine, Never>
  typealias PropertyNameAccumulator = Never
  typealias ClassDefinition = QuickJSClassDefinition

  var count: Double

  init(count: Double) {
    self.count = count
  }

  static var jsClassDefinition: QuickJSClassDefinition {
    var definition = QuickJSClassDefinition()
    definition.className = "QuickJSStaticMemberNode"
    definition.staticValues = [
      JSStaticValue(
        name: "count",
        attributes: .dontDelete,
        getProperty: { context, this in
          guard let instance = try? Self.tryDecode(this, in: context) else {
            return .exception(
              SwiftJavaScript.JSValue<QuickJSEngine>(string: "failed to decode node", in: context)
            )
          }
          return .value(SwiftJavaScript.JSValue<QuickJSEngine>(number: instance.count, in: context))
        },
        setProperty: { context, this, value in
          guard let instance = try? Self.tryDecode(this, in: context) else {
            return .exception(
              SwiftJavaScript.JSValue<QuickJSEngine>(string: "failed to decode node", in: context)
            )
          }
          instance.count = value.toDouble(in: context)
          return .value(SwiftJavaScript.JSValue<QuickJSEngine>(undefinedIn: context))
        }
      )
    ]
    definition.staticFunctions = [
      JSStaticFunction(name: "describe", attributes: .none) { context, this, arguments in
        guard let instance = try? Self.tryDecode(this, in: context),
          arguments.count == 1
        else {
          return .value(SwiftJavaScript.JSValue<QuickJSEngine>(undefinedIn: context))
        }
        return arguments.unpack(at: 0, in: context) { prefix in
          .value(
            SwiftJavaScript.JSValue<QuickJSEngine>(
              string: "\(prefix.toString(in: context)):\(instance.count)",
              in: context
            )
          )
        }
      }
    ]
    return definition
  }
}

private let quickJSLifecycleEvents = Mutex<[String]>([])

private final class QuickJSLifecycleNode: JSClassValueConvertible, @unchecked Sendable {
  typealias Engine = QuickJSEngine
  typealias ParentClass = JSClassParentDescriptor<QuickJSEngine, Never>
  typealias PropertyNameAccumulator = Never
  typealias ClassDefinition = QuickJSClassDefinition

  static var jsClassDefinition: QuickJSClassDefinition {
    var definition = QuickJSClassDefinition()
    definition.className = "QuickJSLifecycleNode"
    definition.initialize = { _, _ in
      quickJSLifecycleEvents.withLock {
        $0.append("initialize")
      }
    }
    definition.finalize = { _ in
      quickJSLifecycleEvents.withLock {
        $0.append("finalize")
      }
    }
    return definition
  }
}

private final class QuickJSRuntimeParentNode: JSClassValueConvertible, @unchecked Sendable {
  typealias Engine = QuickJSEngine
  typealias ParentClass = JSClassParentDescriptor<QuickJSEngine, Never>
  typealias PropertyNameAccumulator = Never
  typealias ClassDefinition = QuickJSClassDefinition

  static var jsClassDefinition: QuickJSClassDefinition {
    var definition = QuickJSClassDefinition()
    definition.className = "QuickJSRuntimeParentNode"
    return definition
  }
}

private final class QuickJSRuntimeChildNode: JSClassValueConvertible, @unchecked Sendable {
  typealias Engine = QuickJSEngine
  typealias ParentClass = JSClassParentDescriptor<QuickJSEngine, Never>
  typealias PropertyNameAccumulator = Never
  typealias ClassDefinition = QuickJSClassDefinition

  static var jsClassDefinition: QuickJSClassDefinition {
    var definition = QuickJSClassDefinition()
    definition.className = "QuickJSRuntimeChildNode"
    definition.parentClass = .for(QuickJSRuntimeParentNode.self)
    return definition
  }
}

@Test func quickJSClassValueConvertibleRoundTripsReferenceIdentity() async throws {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  try await context.withInstantContext { context throws in
    let instance = QuickJSExportedNode(name: "leaf", count: 4)
    let encoded = try QuickJSExportedNode.tryEncode(instance, in: context)
    let decoded = try QuickJSExportedNode.tryDecode(encoded, in: context)

    #expect(decoded === instance)
  }
}

@Test func quickJSClassValueConvertibleCachesClassesPerRuntime() async throws {
  let first = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())
  let second = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  try await first.withInstantContext { context throws in
    let instance = QuickJSExportedNode(name: "first", count: 1)
    let encoded = try QuickJSExportedNode.tryEncode(instance, in: context)
    encoded.setProperty("updated", forKey: "name", in: context)
    let decoded = try QuickJSExportedNode.tryDecode(encoded, in: context)

    #expect(decoded === instance)
    #expect(instance.name == "updated")
    #expect(encoded.getProperty(forKey: "count", in: context).toDouble(in: context) == 1)
  }

  try await second.withInstantContext { context throws in
    let instance = QuickJSExportedNode(name: "second", count: 2)
    let encoded = try QuickJSExportedNode.tryEncode(instance, in: context)
    encoded.setProperty(3, forKey: "count", in: context)
    let decoded = try QuickJSExportedNode.tryDecode(encoded, in: context)

    #expect(decoded === instance)
    #expect(instance.count == 3)
    #expect(encoded.getProperty(forKey: "name", in: context).toString(in: context) == "second")
  }
}

@Test func quickJSRuntimeAwareParentLookupUsesSameRuntime() async {
  let first = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())
  let second = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await first.withInstantContext { context in
    guard QuickJSEngine.runtimeHandle(for: context.driverContextHandle) != nil else {
      Issue.record("Expected QuickJS runtime handle")
      return
    }
    let childDefinition = QuickJSRuntimeChildNode.jsClassDefinition
    #expect(childDefinition.parentClass == .for(QuickJSRuntimeParentNode.self))

    do {
      let encoded = try QuickJSRuntimeChildNode.tryEncode(QuickJSRuntimeChildNode(), in: context)
      let privateData: UnsafeMutableRawPointer?
      switch QuickJSEngine.classObjectPrivateData(
        from: encoded.borrowHandle(),
        in: context.driverContextHandle
      ) {
      case .value(let data):
        privateData = data
      case .exception, nil:
        privateData = nil
      }
      let storage = privateData.map {
        Unmanaged<JSClassAutoObjectStorage<QuickJSClassDefinition>>
          .fromOpaque($0)
          .takeUnretainedValue()
      }
      #expect(storage?.finalizeDepth == 2)
    } catch {
      Issue.record("Expected QuickJS child instance to encode with parent definition lookup")
    }

    do {
      let parent = try QuickJSRuntimeParentNode.tryEncode(QuickJSRuntimeParentNode(), in: context)
      let child = try QuickJSRuntimeChildNode.tryEncode(QuickJSRuntimeChildNode(), in: context)
      context.withGlobalObject { global in
        global.setProperty(parent, forKey: "parentNode", in: context)
        global.setProperty(child, forKey: "childNode", in: context)
      }
      let prototypeResult = context.evaluateScript(
        "Object.getPrototypeOf(Object.getPrototypeOf(childNode)) === Object.getPrototypeOf(parentNode)"
      )
      switch consume prototypeResult {
      case .value(let value):
        let matchesPrototypeChain = value.toBool(in: context)
        #expect(matchesPrototypeChain)
      case .exception:
        Issue.record("Expected QuickJS child class prototype to materialize parent in same runtime")
      }
    } catch {
      Issue.record("Expected QuickJS parent and child classes to encode in the same runtime")
    }
  }

  await second.withInstantContext { context in
    guard QuickJSEngine.runtimeHandle(for: context.driverContextHandle) != nil else {
      Issue.record("Expected QuickJS runtime handle")
      return
    }
    let childDefinition = QuickJSRuntimeChildNode.jsClassDefinition
    #expect(childDefinition.parentClass == .for(QuickJSRuntimeParentNode.self))
  }
}

@Test func quickJSClassBackedObjectSupportsDynamicPropertiesAndMethods() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let instance = QuickJSExportedNode(name: "leaf", count: 4)
    global.setProperty(
      instance,
      forKey: ("node"),
      in: context
    )

    let readResult = context.evaluateScript("node.name + ':' + String(node.count)")
    switch consume readResult {
    case .value(let value):
      #expect(value.toString(in: context) == "leaf:4")
    case .exception:
      Issue.record("Expected QuickJS class-backed properties to be readable")
    }

    let writeResult = context.evaluateScript(
      "node.name = 'branch'; node.count = 9; node.label('id')")
    switch consume writeResult {
    case .value(let value):
      #expect(value.toString(in: context) == "id:branch:9.0")
    case .exception:
      Issue.record("Expected QuickJS class-backed properties and methods to work")
    }

    #expect(instance.name == "branch")
    #expect(instance.count == 9)

    let expandoResult = context.evaluateScript(
      "node.extra = 11; var before = node.extra + ':' + ('extra' in node); "
        + "delete node.extra; before + ':' + ('extra' in node)")
    switch consume expandoResult {
    case .value(let value):
      #expect(value.toString(in: context) == "11:true:false")
    case .exception:
      Issue.record("Expected dynamic QuickJS class-backed objects to support expando properties")
    }
  }
}

@Test func quickJSClassBackedObjectSupportsStaticMembers() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<QuickJSEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let instance = QuickJSStaticMemberNode(count: 3)
    global.setProperty(
      instance,
      forKey: ("node"),
      in: context
    )

    let result = context.evaluateScript("node.count = 7; node.describe('value')")
    switch consume result {
    case .value(let value):
      #expect(value.toString(in: context) == "value:7.0")
    case .exception:
      Issue.record("Expected QuickJS static class members to be visible")
    }

    #expect(instance.count == 7)

    let attributesResult = context.evaluateScript(
      "var deleteCount = delete node.count; "
        + "var countStillPresent = 'count' in node; "
        + "var deleteDescribe = delete node.describe; "
        + "[deleteCount, countStillPresent, deleteDescribe, 'describe' in node].join(':')")
    switch consume attributesResult {
    case .value(let value):
      #expect(value.toString(in: context) == "false:true:true:false")
    case .exception:
      Issue.record("Expected QuickJS static member attributes to be enforced")
    }

    let expandoResult = context.evaluateScript(
      "node.extra = 11; var before = node.extra + ':' + ('extra' in node); "
        + "delete node.extra; before + ':' + ('extra' in node)")
    switch consume expandoResult {
    case .value(let value):
      #expect(value.toString(in: context) == "11:true:false")
    case .exception:
      Issue.record("Expected QuickJS class-backed objects to support expando properties")
    }

    let undefinedExpandoResult = context.evaluateScript(
      "node.extra = undefined; 'extra' in node")
    switch consume undefinedExpandoResult {
    case .value(let value):
      let hasExtra = value.toBool(in: context)
      #expect(hasExtra)
    case .exception:
      Issue.record("Expected QuickJS has_property to see undefined-valued own properties")
    }
  }
}

@Test func quickJSClassBackedObjectRunsLifecycleCallbacks() async {
  quickJSLifecycleEvents.withLock {
    $0.removeAll()
  }
  let virtualMachine = JSVirtualMachine<QuickJSEngine>()
  let context = JSContext(virtualMachine: virtualMachine)

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(
      QuickJSLifecycleNode(),
      forKey: ("node"),
      in: context
    )
    #expect(
      quickJSLifecycleEvents.withLock {
        $0 == ["initialize"]
      })
    _ = context.evaluateScript("node = null")
  }
  virtualMachine.gc()

  #expect(
    quickJSLifecycleEvents.withLock {
      $0 == ["initialize", "finalize"]
    })
}
