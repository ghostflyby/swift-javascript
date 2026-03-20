@inline(__always)
package func countTypePack<each T>(_ types: repeat (each T).Type) -> Int {
  var count = 0
  for _ in repeat each types {
    count += 1
  }
  return count
}
