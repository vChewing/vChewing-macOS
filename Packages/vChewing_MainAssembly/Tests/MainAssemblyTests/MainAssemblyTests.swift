@testable import MainAssembly
import XCTest

final class MainAssemblyTests: XCTestCase {
  override func setUpWithError() throws {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
    UserDefaults.pendingUnitTests = true
  }

  override func tearDownWithError() throws {
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
  }

  func testExample() throws {}
}
