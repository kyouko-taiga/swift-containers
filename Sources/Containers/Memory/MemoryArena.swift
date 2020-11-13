/// A fast (but limited) allocate arena for values of a single type.
///
/// A memory arena is essentially a large pre-allocated buffer of memory that can be used to store
/// individual objects, mitigating the overhead of memory allocation/deallocation.
///
/// Automatic Garbage Collection:
/// -----------------------------
///
/// You can use an arena as an alternate strategy for automatic garbage collection. Every instances
/// keep track of which parts of their buffer are "allocated" in a small ledger, so that you may
/// repurpose individual chunks.
///
///     let arena = MemoryArena<String>(capacity: 1024)
///     if let p = arena.allocate() {
///       print(p)
///       arena.deallocate(p)
///     }
///
/// A memory arena conforms `Collection` so you can iterate over all active pointers, which can be
/// useful to avoid keeping track of all allocated pointers in your own data structures. Since it
/// is deallocated at once, it is safe to create cyclic references between the objects it contains.
public final class MemoryArena<Element> {

  /// Creates a new arena.
  ///
  /// - Parameter capacity: The maximum number `Element`'s instances the arena can hold.
  public init(capacity: Int = 32) {
    buffer = .allocate(capacity: capacity)
    ledger = .allocate(capacity: (capacity + 31) / 32)
    top = buffer.baseAddress

    for i in 0 ..< ledger.count {
      let k = (i + 1) * 32 - capacity
      if k <= 0 {
        ledger[i] = ~0
      } else {
        ledger[i] = ~0 &>> k
      }
    }
  }

  deinit {
    for pointer in self {
      pointer.deinitialize(count: 1)
    }

    buffer.deallocate()
    ledger.deallocate()
  }

  /// The arena's internal buffer.
  private let buffer: UnsafeMutableBufferPointer<Element>

  /// A pointer to the next available location in the arena's buffer.
  private var top: UnsafeMutablePointer<Element>?

  /// The arena's availability ledger.
  private let ledger: UnsafeMutableBufferPointer<UInt32>

  /// Allocates the memory of a single `Element` instance.
  ///
  /// - Returns: An uninitialized pointer to `Element`, or `nil` if the arena ran out of memory.
  ///
  /// - Important: Do **not** deallocate arena pointers outside of the arena; attempting to do so
  ///   so will result in undefined behavior. Use the arena's `deallocate(:)` method instead.
  public func allocate() -> UnsafeMutablePointer<Element>? {
    guard let base = buffer.baseAddress
      else { return nil }

    // Fast path, O(1): attempt to allocate at top of the memory stack.
    let distance = base.distance(to: top!)
    if distance < buffer.count {
      let address = top!
      let index = distance / 32
      ledger[index] &= ~(1 &<< (distance % 32))

      self.top = top!.successor()
      return address
    }

    // Slow path, O(n): The top pointer is at the end of the buffer; search for a free space.
    for i in 0 ..< ledger.count {
      let bitset = ledger[i]
      var mask = bitset & UInt32(bitPattern: -Int32(bitPattern: bitset))

      if mask != 0 {
        ledger[i] &= ~mask
        var address = base.advanced(by: i * 32)

        mask = mask &>> 1
        while mask != 0 {
          address = address.advanced(by: 1)
          mask = mask &>> 1
        }

        return address
      }
    }

    // There is not enough space to allocate the requested size.
    return nil
  }

  /// Deallocates a pointer.
  ///
  /// Calling this method has no effect if `pointer` is not currently allocated or if it does not
  /// point into the arena.
  ///
  /// - Parameter pointer: The pointer to deallocate. `pointer` must not be initialized or
  ///   `Element` must be a trivial type.
  public func deallocate(_ pointer: UnsafeMutablePointer<Element>) {
    // Check that the pointer is in bounds.
    guard self ~= pointer
      else { return }

    // Check that the pointer is indeed allocated.
    var distance = buffer.baseAddress!.distance(to: pointer)
    guard ledger[distance / 32] & (1 &<< (distance % 32)) != 0
      else { return }

    // Update the ledger.
    ledger[distance / 32] |= 1 &<< (distance % 32)

    // Update the top pointer.
    guard pointer == top!.predecessor()
      else { return }

    while distance >= 0 {
      guard ledger[distance / 32] & (1 &<< (distance % 32)) != 0
        else { break }

      distance -= 1
      top = top!.predecessor()
    }
  }

  /// Returns whether a pointer lies within the bounds of the given arena.
  ///
  /// - Parameters:
  ///   - pool: The arena in which the pointer should be contained.
  ///   - pointer: The pointer to check.
  public static func ~= (arena: MemoryArena, pointer: UnsafeMutablePointer<Element>) -> Bool {
    guard let base = arena.buffer.baseAddress
      else { return false }
    return base.distance(to: pointer) <= arena.buffer.count
  }

}

extension MemoryArena: Collection {

  public var startIndex: Int {
    guard !ledger.isEmpty
      else { return buffer.count }

    if (ledger[0] & 1) != 1 {
      return 0
    } else {
      return index(after: 0)
    }
  }

  public var endIndex: Int {
    return buffer.count
  }

  public func index(after position: Int) -> Int {
    let start = (position + 1) / 32
    for i in start ..< ledger.count {
      var bitset = ledger[i]
      if i == start {
        bitset = bitset | ~(~0 &<< UInt32(truncatingIfNeeded: position % 32 + 1))
      }

      var mask = ~bitset & (bitset &+ 1)
      if mask != 0 {
        var next = i * 32

        mask = mask &>> 1
        while mask != 0 {
          next = next + 1
          mask = mask &>> 1
        }

        return next
      }
    }
    return buffer.count
  }

  public subscript(position: Int) -> UnsafeMutablePointer<Element> {
    return buffer.baseAddress!.advanced(by: position)
  }

}
