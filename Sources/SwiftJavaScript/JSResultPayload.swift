public enum JSResultPayload<Value: ~Copyable>: ~Copyable {
  case value(Value)
  case exception(Value)
}
