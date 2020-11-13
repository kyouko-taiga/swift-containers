import XCTest
@testable import Containers

final class MemoryArenaTests: XCTestCase {

  func testFastAllocate() {
    let arena = MemoryArena<Int>(capacity: 48)

    var p = arena.allocate()
    XCTAssertNotNil(p)

    for _ in 1 ..< 48 {
      let q = arena.allocate()
      XCTAssertNotNil(q)
      XCTAssert(p?.successor() == q)
      p = q
    }

    XCTAssertNil(arena.allocate())
  }

  func testSlowAllocate() {
    let arena = MemoryArena<Int>(capacity: 48)

    var pointers: [UnsafeMutablePointer<Int>] = []
    for _ in 0 ..< 48 {
      let q = arena.allocate()
      XCTAssertNotNil(q)
      pointers.append(q!)
    }

    for i in stride(from: 1, to: 48, by: 2) {
      arena.deallocate(pointers[i])
    }

    for _ in 0 ..< 24 {
      let q = arena.allocate()
      XCTAssertNotNil(q)
    }

    XCTAssertNil(arena.allocate())
  }

}
