import JavaScriptCore
import Testing

@testable import SwiftJavaScript
@testable import SwiftyJavaScriptCore

// MARK: - Context-free JavaScriptCore inputs
//
// The engine representation of a property key and a prepared script is a
// `JSStringRef`, which is not tied to a context. The direct initializers
// create both without one; the tests use the same instances through two
// contexts of the same VM.

@Suite
struct JSCContextFreeInputTests {
  @Test
  func detachedKeyAndScriptWorkAcrossContexts() async {
    let virtualMachine = await JSCVirtualMachine(.nonblocking)
    let first = await JSCContext(virtualMachine: virtualMachine, .nonblocking)
    let second = await JSCContext(virtualMachine: virtualMachine, .nonblocking)
    let otherVirtualMachine = await JSCVirtualMachine(.nonblocking)
    let third = await JSCContext(virtualMachine: otherVirtualMachine, .nonblocking)

    let key = JSCPropertyStringKey("shared")
    let script = JSCPreparedScript(source: "6 * 7")

    let firstKeyText = await first.withInstantContext { scope -> String in
      scope.makeString(from: key).toString()
    }
    let secondKeyText = await second.withInstantContext { scope -> String in
      let objectResult = scope.makeObject()
      let object: JSCValue
      switch consume objectResult {
      case .value(let value):
        object = scope.persist(value)
      case .exception:
        return "<exception>"
      }

      let text = scope.persist(scope.makeString("value"))
      _ = object.setProperty(key, to: text, attributes: .none, in: scope)
      let readResult = object.getProperty(key, in: scope)
      switch consume readResult {
      case .value(let value):
        return value.toString()
      case .exception:
        return "<exception>"
      }
    }

    let firstSum = await first.withInstantContext { scope -> Double in
      let result = scope.evaluateScript(script, sourceURL: nil, startingLineNumber: 1)
      switch consume result {
      case .value(let value):
        return value.toNumber()
      case .exception:
        return .nan
      }
    }
    let secondSum = await second.withInstantContext { scope -> Double in
      let result = scope.evaluateScript(script, sourceURL: nil, startingLineNumber: 1)
      switch consume result {
      case .value(let value):
        return value.toNumber()
      case .exception:
        return .nan
      }
    }
    let thirdKeyText = await third.withInstantContext { scope -> String in
      scope.makeString(from: key).toString()
    }
    let thirdSum = await third.withInstantContext { scope -> Double in
      let result = scope.evaluateScript(script, sourceURL: nil, startingLineNumber: 1)
      switch consume result {
      case .value(let value):
        return value.toNumber()
      case .exception:
        return .nan
      }
    }

    #expect(firstKeyText == "shared")
    #expect(secondKeyText == "value")
    #expect(firstSum == 42)
    #expect(secondSum == 42)
    #expect(thirdKeyText == "shared")
    #expect(thirdSum == 42)
  }

  /// A manual class is materialized with `JSClassCreate`, which takes no
  /// context. The resulting class ref is process-wide and can create host
  /// objects in contexts of different VMs.
  @Test
  func manualClassesAreContextFree() async {
    var definition = SwiftJavaScript.JSEngineClassDefinition<
      JSCContext, JSCClass, JSPropertyNameAccumulatorRef
    >()
    definition.className = "ContextFreeManualClass"
    let jsClass = JSCClass(defination: definition)

    let firstVirtualMachine = await JSCVirtualMachine(.nonblocking)
    let secondVirtualMachine = await JSCVirtualMachine(.nonblocking)
    let first = await JSCContext(virtualMachine: firstVirtualMachine, .nonblocking)
    let second = await JSCContext(virtualMachine: secondVirtualMachine, .nonblocking)

    let firstMadeObject = await first.withInstantContext { scope -> Bool in
      let privateData = UnsafeMutableRawPointer(bitPattern: 0x1)!
      guard let object = scope.makeHostObject(of: jsClass, privateData: privateData) else {
        return false
      }
      _ = object
      return true
    }
    let secondMadeObject = await second.withInstantContext { scope -> Bool in
      let privateData = UnsafeMutableRawPointer(bitPattern: 0x1)!
      guard let object = scope.makeHostObject(of: jsClass, privateData: privateData) else {
        return false
      }
      _ = object
      return true
    }

    #expect(firstMadeObject)
    #expect(secondMadeObject)
  }
}
