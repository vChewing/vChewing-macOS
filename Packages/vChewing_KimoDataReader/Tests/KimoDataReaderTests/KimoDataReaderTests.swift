@testable import ObjcKimoCommunicator
import XCTest

final class KimoDataReaderTests: XCTestCase {
  // 先運行奇摩輸入法，再跑這個測試。
  func testExample() throws {
    let shared = ObjcKimoCommunicator()
    print(shared.establishConnection())
  }
}
