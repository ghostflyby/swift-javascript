import SwiftJavaScript
import Synchronization
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
          context.makeFunction(named: "label") { context, this, arguments in
            guard let instance = try? Self.tryDecode(this, in: context),
              arguments.count == 1
            else {
              return .value(SwiftJavaScript.JSValue<QuickJSEngine>(undefinedIn: context))
            }
            return arguments.unpack(at: 0, in: context) { prefix in
              .value(
                SwiftJavaScript.JSValue<QuickJSEngine>(
                  string: "\(prefix.toString(in: context)):\(instance.name):\(instance.count)",
                  in: context
                )
              )
            }
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
      forKey: SwiftJavaScript.JSStringManaged<QuickJSEngine>("node"),
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
      forKey: SwiftJavaScript.JSStringManaged<QuickJSEngine>("node"),
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
      forKey: SwiftJavaScript.JSStringManaged<QuickJSEngine>("node"),
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
