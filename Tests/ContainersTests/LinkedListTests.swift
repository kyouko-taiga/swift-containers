import XCTest
@testable import Containers

final class LinkedListTests: XCTestCase {

  func testIsEmpty() {
    let l0 = LinkedList<Int>()
    XCTAssertTrue(l0.isEmpty)
  }

}
