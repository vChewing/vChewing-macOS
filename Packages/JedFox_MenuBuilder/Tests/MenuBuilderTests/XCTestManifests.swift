import XCTest

#if !canImport(ObjectiveC)
  public func allTests() -> [XCTestCaseEntry] {
    [
      testCase(MenuBuilderTests.allTests)
    ]
  }
#endif
