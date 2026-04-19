@frozen public struct JSValueStorage: Sendable {
  public var word0: UInt64
  public var word1: UInt64
  public var word2: UInt64

  public init(word0: UInt64 = 0, word1: UInt64 = 0, word2: UInt64 = 0) {
    self.word0 = word0
    self.word1 = word1
    self.word2 = word2
  }
}
