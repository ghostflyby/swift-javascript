// MARK: - Shared ArrayBuffer byte storage (S10)
//
// Both engines hand externally allocated, zero-filled or copied bytes to their
// no-copy ArrayBuffer constructor. Allocating, copying, and releasing that
// storage is engine-independent, so it lives in core; each engine only calls
// its own constructor through the `JSArrayBufferHostScope` requirement, and
// the core helper keeps the "rejected bytes are released exactly once" rule.

/// The C deallocator both engines pass to their no-copy buffer constructor.
/// The allocation is a plain `UnsafeMutableRawPointer.allocate`, so the
/// matching release is `deallocate()`.
package let jsArrayBufferBytesDeallocator:
  @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = {
    bytes,
    _ in
    bytes?.deallocate()
  }

/// A zero-filled allocation of `byteLength` bytes. Empty buffers have no
/// storage to hand over, so this returns `nil` for them (the engines accept a
/// nil pointer for a zero-length buffer).
package func allocateZeroedArrayBufferBytes(byteLength: Int) -> UnsafeMutableRawPointer? {
  guard byteLength > 0 else {
    return nil
  }

  let pointer = UnsafeMutableRawPointer.allocate(
    byteCount: byteLength,
    alignment: MemoryLayout<UInt8>.alignment
  )
  pointer.initializeMemory(as: UInt8.self, repeating: 0, count: byteLength)
  return pointer
}

/// A copy of `bytes`. The copy runs inside the array's own pointer scope, so
/// no buffer pointer escapes it.
package func allocateArrayBufferBytes(copying bytes: [UInt8]) -> UnsafeMutableRawPointer? {
  guard !bytes.isEmpty else {
    return nil
  }

  let pointer = UnsafeMutableRawPointer.allocate(
    byteCount: bytes.count,
    alignment: MemoryLayout<UInt8>.alignment
  )
  bytes.withUnsafeBytes { source in
    pointer.copyMemory(from: source.baseAddress!, byteCount: bytes.count)
  }
  return pointer
}

/// A copy of an existing raw buffer.
package func allocateArrayBufferBytes(
  copying bytes: UnsafeRawBufferPointer
) -> UnsafeMutableRawPointer? {
  guard let base = bytes.baseAddress, bytes.count > 0 else {
    return nil
  }

  let pointer = UnsafeMutableRawPointer.allocate(
    byteCount: bytes.count,
    alignment: MemoryLayout<UInt8>.alignment
  )
  pointer.copyMemory(from: base, byteCount: bytes.count)
  return pointer
}

/// The synchronous window operation the no-copy ArrayBuffer helper needs from
/// an instant context: hand the bytes to the engine's buffer constructor and
/// adopt the engine's creation reference onto the window arena exactly once.
///
/// `nil` means the engine rejected the creation and never took the bytes; the
/// core helper then releases them. Implementations must not call the
/// deallocator on the rejection path — that would release the bytes twice.
package protocol JSArrayBufferHostScope: JSInstantContext, ~Copyable {
  @_lifetime(borrow self)
  func adoptArrayBufferBytesNoCopy(
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator:
      @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
      ) -> Void,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> Value?
}

/// Hand `bytes` to the engine as a no-copy ArrayBuffer and adopt the creation
/// reference into `context`.
///
/// The engine either takes ownership of the bytes (and calls `bytesDeallocator`
/// when the buffer dies) or rejects the creation. On rejection the engine never
/// took the bytes, so this releases the allocation here — exactly once — and
/// returns `nil`; the caller reports the failure. On success the engine adopts
/// the creation reference exactly once on the calling window's arena.
@_lifetime(borrow context)
package func adoptArrayBufferBytesNoCopy<C: JSArrayBufferHostScope & ~Copyable>(
  _ bytes: UnsafeMutableRawPointer?,
  byteLength: Int,
  in context: borrowing C,
  bytesDeallocator:
    @convention(c) (
      UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
    ) -> Void = jsArrayBufferBytesDeallocator
) -> C.Value? {
  guard
    let value = context.adoptArrayBufferBytesNoCopy(
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: bytesDeallocator,
      deallocatorContext: nil
    )
  else {
    bytesDeallocator(bytes, nil)
    return nil
  }

  return value
}
