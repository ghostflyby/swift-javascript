import SwiftJavaScript

package typealias JSValueHandle<E: JSEngineValueTypes> = E.ValueHandle

/// The `~Copyable` ownership-carrier counterpart of `JSValueHandle`:
/// creation results, scope-arena elements, and ownership handoffs.
package typealias JSOwnedValueHandle<E: JSEngineValueTypes> = E.OwnedValueHandle
