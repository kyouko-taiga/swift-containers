public final class MemoryPool {

  public init() {
  }

  deinit {
    var cursor = head
    while let chunk = cursor?.pointee {
      if chunk.base.tag & 0b10 == 0b10 {
        chunk.base.address!.deallocate()
      }

      let next = chunk.next
      cursor!.deinitialize(count: 1)
      cursor!.deallocate()
      cursor = next
    }
  }

  /// The head of the pool's chunk list.
  private var head: UnsafeMutablePointer<Chunk>?

  /// A chunk of memory.
  private struct Chunk {

    /// The base address of the chunk.
    ///
    /// The lowest bit of the tag determines whether the chunk is free. The second lowest indicates
    /// whether its address corresponds to the actual base address of a memory block, or if it
    /// points into the middle of one.
    var base: TaggedRawPointer

    /// The number of bytes in the chunk.
    var byteCount: Int

    /// A pointer to the next chunk.
    var next: UnsafeMutablePointer<Chunk>?

  }

  public func allocate(byteCount: Int, alignment: Int) -> UnsafeMutableRawPointer {
    let alignment = max(1, alignment)
    var chunk = head

    while chunk != nil {
      if let address = allocate(byteCount: byteCount, alignment: alignment, in: &chunk!) {
        return address
      }
      chunk = chunk?.pointee.next
    }

    // No space available; allocate a new chunk.
    let adjustment = max(0, alignment - MemoryLayout<Int>.alignment)
    let bufferByteCount = max(byteCount + adjustment, MemoryPool.minChunkSize)
    let buffer = UnsafeMutableRawPointer.allocate(
      byteCount: bufferByteCount,
      alignment: MemoryLayout<Int>.alignment)

    let tail = head
    head = .allocate(capacity: 1)
    head?.initialize(to: Chunk(
      base: TaggedRawPointer(address: buffer, tag: 0b11),
      byteCount: bufferByteCount,
      next: tail))

    return allocate(byteCount: byteCount, alignment: alignment, in: &head!)!
  }

  public func deallocate(_ pointer: UnsafeMutableRawPointer) {
    var pred: UnsafeMutablePointer<Chunk>?
    var cursor = head

    while cursor != nil {
      if cursor!.pointee.base.address == pointer {
        // Set the chunk's free flag.
        cursor!.pointee.base.tag |= 0b01

        // Attempt to merge the chunk with its predecessor and/or successor if possible
        if let next = cursor!.pointee.next, next.pointee.base.tag & 0b11 == 0b01 {
          cursor!.pointee.byteCount += next.pointee.byteCount
          cursor!.pointee.next = next.pointee.next
        }
        if (cursor!.pointee.base.tag & 0b10 == 0) && (pred!.pointee.base.tag & 0b01 == 0b01) {
          pred!.pointee.byteCount += cursor!.pointee.byteCount
          pred!.pointee.next = cursor!.pointee.next
        }

        return
      }

      pred = cursor
      cursor = cursor!.pointee.next
    }
  }

  private func allocate(
    byteCount: Int,
    alignment: Int,
    in chunk: inout UnsafeMutablePointer<Chunk>
  ) -> UnsafeMutableRawPointer? {
    // Check if the chunk is free.
    guard chunk.pointee.base.tag & 0b01 == 0b01
      else { return nil }

    // Get the first address that satisfies the requested alignment.
    var addressValue = Int(bitPattern: chunk.pointee.base.address!)
    if addressValue % alignment != 0 {
      addressValue += alignment - (addressValue % alignment)
    }
    let address = UnsafeMutableRawPointer(bitPattern: addressValue)!

    // Check if the chunk is large enough to allocate the requested number of bytes.
    let offset = chunk.pointee.base.address!.distance(to: address)
    guard chunk.pointee.byteCount - offset >= byteCount
      else { return nil }

    // Split the chunk if the computed address had to be offset.
    if offset > 0 {
      let tail = chunk.pointee.next
      chunk.pointee.next = .allocate(capacity: 1)
      chunk.pointee.next!.initialize(to: Chunk(
        base: TaggedRawPointer(address: address, tag: 0b01),
        byteCount: chunk.pointee.byteCount - offset,
        next: tail))
      chunk.pointee.byteCount = offset
      chunk = chunk.pointee.next!
    }

    // Unset the chunk's free flag.
    chunk.pointee.base.tag &= 0b10

    // Split the chunk if it is larger than the requested size.
    if chunk.pointee.byteCount > byteCount {
      let tail = chunk.pointee.next
      chunk.pointee.next = .allocate(capacity: 1)
      chunk.pointee.next?.initialize(to: Chunk(
        base: TaggedRawPointer(address: address.advanced(by: byteCount), tag: 0b01),
        byteCount: chunk.pointee.byteCount - byteCount,
        next: tail))
      chunk.pointee.byteCount = byteCount
    }

    return address
  }

  public func foo() {
    var cursor = head
    while let chunk = cursor?.pointee {
      print(chunk.byteCount, ((chunk.base.tag & 0b10) >> 1, chunk.base.tag & 0b1))
      cursor = chunk.next
    }
  }

  static let minChunkSize = 512

}
