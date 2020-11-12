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
///     if let p = arena.allocate(initilizingWith: { p in
///       p.initialize(to: "Hello")
///     }) {
///       p.pointee += ", World!"
///       print(p.pointee)
///       arena.deallocate(p)
///     }
///
/// A memory arena conforms `Collection` so you can iterate over all active pointers, which can be
/// useful to avoid keeping track of all allocated pointers in your own data structures. Since it
/// is deallocated at once, it is safe to create cyclic references between the objects it contains.
public final class MemoryArena<Element> {

  public init(capacity: Int = 32) {
    buffer = .allocate(capacity: capacity)
    ledger = .allocate(capacity: (capacity + 31) / 32)

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

  /// The arena's availability ledger.
  private let ledger: UnsafeMutableBufferPointer<UInt32>

  /// Allocates the memory of a single `Element` instance and initializes it the given closure.
  ///
  /// - Parameter initializer: A closure that accepts an uninitialized pointer to element and
  ///   initializes it.
  /// - Returns: An initialized pointer to `Element`, or `nil` if the arena ran out of memory.
  ///
  /// - Important: Do **not** deinitialize nor deallocate arena pointers outside of the arena;
  ///   attempting to do so so will result in undefined behavior. Use the arena's `deallocate(:)`
  ///   method instead.
  public func allocate(
    initilizingWith initializer: (UnsafeMutablePointer<Element>) throws -> Void
  ) rethrows -> UnsafeMutablePointer<Element>? {
    guard let base = buffer.baseAddress
      else { return nil }

    for i in 0 ..< ledger.count {
      let bitset = ledger[i]
      var mask = bitset & UInt32(bitPattern: -Int32(bitPattern: bitset))

      if mask != 0 {
        ledger[i] &= ~mask
        var ptr = base.advanced(by: i * 32)

        mask = mask &>> 1
        while mask != 0 {
          ptr = ptr.advanced(by: 1)
          mask = mask &>> 1
        }

        do {
          try initializer(ptr)
          return ptr
        } catch {
          ledger[i] |= bitset & UInt32(bitPattern: -Int32(bitPattern: bitset))
          throw error
        }
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
    guard isInBounds(pointer)
      else { return }

    pointer.deallocate()

    let distance = buffer.baseAddress!.distance(to: pointer)
    let index = distance / 32
    ledger[index] |= 1 &<< (distance % 32)
  }

  /// Checks whether the given pointer lies within the bounds of the arena's buffer.
  private func isInBounds(_ pointer: UnsafeMutablePointer<Element>) -> Bool {
    guard let base = buffer.baseAddress
      else { return false }
    return base.distance(to: pointer) <= buffer.count
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
