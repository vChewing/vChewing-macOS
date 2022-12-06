import XCTest

@testable import MenuBuilder

private class MyMenuItem: NSMenuItem {
  var value: Int?
}

final class MenuBuilderTests: XCTestCase {
  func testExample() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    let menu = NSMenu {
      MenuItem("Hello, world!")
      SeparatorItem()
      MenuItem("Title")
      IndentGroup {
        MenuItem("Item 1")
        IndentGroup {
          MenuItem("Item 2")
        }
        MenuItem("Item 3")
      }
      CustomMenuItem(MyMenuItem())
        .set(\.value, to: 42)
    }
    XCTAssertEqual(menu.items.count, 7)
    XCTAssertEqual(menu.items[0].title, "Hello, world!")
    XCTAssertTrue(menu.items[1].isSeparatorItem)
    XCTAssertEqual(menu.items.map(\.indentationLevel), [0, 0, 0, 1, 2, 1, 0])
    XCTAssertNotNil(menu.items[6] as? MyMenuItem)
    XCTAssertEqual((menu.items[6] as? MyMenuItem)?.value, 42)
  }

  static var allTests = [
    ("testExample", testExample)
  ]
}
