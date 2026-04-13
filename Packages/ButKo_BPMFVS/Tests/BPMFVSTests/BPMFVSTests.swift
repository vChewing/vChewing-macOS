@testable import BPMFVS
import Testing

@Suite("BPMFVSTests")
struct BPMFVSTests {
  @Test
  func testBundledFileAccess() async throws {
    _ = try #require(BPMFVS.getBPMFVSDataURL())
  }
}
