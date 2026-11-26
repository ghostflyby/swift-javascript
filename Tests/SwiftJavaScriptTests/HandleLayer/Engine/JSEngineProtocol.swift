import SwiftJavaScript

/// Capability composition for engines that support the full value surface:
/// context/runtime value operations, property access, prepared-script
/// evaluation, invocation, and typed arrays.
///
/// This alias only names the driver capabilities. An engine's user-facing
/// types are bound by its context (`JSContext`), not by its engine type.
package typealias JSContextEngine = JSEnginePropertyDriver & JSEnginePreparedScriptDriver

package typealias JSEngine = Sendable & JSContextEngine
  & JSEngineInvocationDriver & JSEngineTypedArrayDriver
