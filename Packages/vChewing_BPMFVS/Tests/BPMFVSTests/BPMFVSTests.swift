@testable import BPMFVS
import Testing

@Suite("BPMFVSTests")
struct BPMFVSTests {
  @Test
  func testBundledFileAccess() async throws {
    _ = try #require(BPMFVS.getBPMFVSDataURL())
  }

  @Test
  func testKeepsPrimaryReadingUntouched() {
    #expect(BPMFVS.convert(value: "咱", reading: "ㄗㄢˊ") == "咱")
  }

  @Test
  func testAddsVariationSelectorForNonPrimaryReading() {
    let expected = "咱" + String(try! #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "咱", reading: "ㄗㄚˊ") == expected)
  }

  @Test
  func testNormalizesTrailingNeutralToneMarker() {
    let expected = "地" + String(try! #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "地", reading: "ㄉㄜ˙") == expected)
  }

  @Test
  func testConvertsMultiCharacterDisplaySegment() {
    let vs1 = String(try! #require(UnicodeScalar(0xE01E1)))
    #expect(BPMFVS.convert(value: "咱地", readings: ["ㄗㄚˊ", "ㄉㄜ˙"]) == "咱\(vs1)地\(vs1)")
  }

  @Test
  func testLeavesMultiCharacterDisplaySegmentUntouchedWhenCountsMismatch() {
    #expect(BPMFVS.convert(value: "咱地", readings: ["ㄗㄚˊ"]) == "咱地")
  }
}
