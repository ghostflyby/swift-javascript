public enum JSValueConversionError: Error {
  case typeMismatch(expected: String, actual: JSType)
  case nonFiniteNumber(target: String)
  case outOfRange(target: String, value: Double)
  case nonInteger(target: String, value: Double)
  case codable(String)
}
