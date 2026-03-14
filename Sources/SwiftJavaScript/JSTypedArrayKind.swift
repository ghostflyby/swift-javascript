public enum JSTypedArrayKind: Sendable, Hashable {
  case int8Array
  case uint8Array
  case uint8ClampedArray
  case int16Array
  case uint16Array
  case int32Array
  case uint32Array
  case float32Array
  case float64Array

  public var bytesPerElement: Int {
    switch self {
    case .int8Array, .uint8Array, .uint8ClampedArray:
      return 1
    case .int16Array, .uint16Array:
      return 2
    case .int32Array, .uint32Array, .float32Array:
      return 4
    case .float64Array:
      return 8
    }
  }
}
