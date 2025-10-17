// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit
import Shared
import XCTest

class CandidateServiceCoordinatorTests: XCTestCase {
  // MARK: Internal

  static let testDataMap: [String] = [
    #"Unicode Metadata: %s"# + "\t" + #"@SEL:copyUnicodeMetadata:"#,
    #"HTML Ruby Zhuyin: %s"# + "\t" + #"@SEL:copyRubyHTMLZhuyinTextbookStyle:"#,
    #"HTML Ruby Pinyin: %s"# + "\t" + #"@SEL:copyRubyHTMLHanyuPinyinTextbookStyle:"#,
    #"Zhuyin Annotation: %s"# + "\t" + #"@SEL:copyInlineZhuyinAnnotationTextbookStyle:"#,
    #"Pinyin Annotation: %s"# + "\t" + #"@SEL:copyInlineHanyuPinyinAnnotationTextbookStyle:"#,
    #"Braille 1947: %s"# + "\t" + #"@SEL:copyBraille1947:"#,
    #"Braille 2018: %s"# + "\t" + #"@SEL:copyBraille2018:"#,
  ]

  func testSelector_FinalSanityCheck() throws {
    assertServiceCountReducedAfterFinalSanityCheck(
      services: Self.testDataMap,
      candidate: "胡桃",
      reading: [] // 故意使用空 Reading
    )
  }

  func testSelector_UnicodeMetadata() throws {
    let expectedResponse =
      "胡 U+80E1 CJK UNIFIED IDEOGRAPH-80E1\n桃 U+6843 CJK UNIFIED IDEOGRAPH-6843"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 0,
      candidate: "胡桃",
      reading: ["ㄏㄨˊ", "ㄊㄠˊ"],
      expected: expectedResponse
    )
  }

  func testSelector_HTMLRubyZhuyinTextbookStyle() throws {
    let expectedResponse =
      "<ruby>甜<rp>(</rp><rt>ㄊㄧㄢˊ</rt><rp>)</rp></ruby><ruby>的<rp>(</rp><rt>˙ㄉㄜ</rt><rp>)</rp></ruby>"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 1,
      candidate: "甜的",
      reading: ["ㄊㄧㄢˊ", "ㄉㄜ˙"],
      expected: expectedResponse
    )
  }

  func testSelector_HTMLRubyPinyinTextbookStyle() throws {
    let expectedResponse =
      "<ruby>鐵<rp>(</rp><rt>tiě</rt><rp>)</rp></ruby><ruby>嘴<rp>(</rp><rt>zuǐ</rt><rp>)</rp></ruby>"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 2,
      candidate: "鐵嘴",
      reading: ["ㄊㄧㄝˇ", "ㄗㄨㄟˇ"],
      expected: expectedResponse
    )
  }

  func testSelector_InlineAnnotationZhuyinTextbookStyle() throws {
    let expectedResponse = "甜(ㄊㄧㄢˊ)的(˙ㄉㄜ)"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 3,
      candidate: "甜的",
      reading: ["ㄊㄧㄢˊ", "ㄉㄜ˙"],
      expected: expectedResponse
    )
  }

  func testSelector_InlineAnnotationTextbookStyle() throws {
    let expectedResponse = "鐵(tiě)嘴(zuǐ)"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 4,
      candidate: "鐵嘴",
      reading: ["ㄊㄧㄝˇ", "ㄗㄨㄟˇ"],
      expected: expectedResponse
    )
  }

  func testSelector_Braille1947() throws {
    let expectedResponse = "⠎⠄⠙⠬⠂⠝⠵⠂⠉⠎⠂⠡⠐⠉⠳⠈⠟⠭⠄"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 5,
      candidate: "幽蝶能留一縷芳",
      reading: ["ㄧㄡ", "ㄉㄧㄝˊ", "ㄋㄥˊ", "ㄌㄧㄡˊ", "ㄧˋ", "ㄌㄩˇ", "ㄈㄤ"],
      expected: expectedResponse
    )
  }

  func testSelector_Braille2018() throws {
    let expectedResponse = "⠳⠁⠙⠑⠂⠝⠼⠂⠇⠳⠂⠊⠆⠇⠬⠄⠋⠦⠁"
    assertCandidateServiceResponse(
      services: Self.testDataMap,
      index: 6,
      candidate: "幽蝶能留一縷芳",
      reading: ["ㄧㄡ", "ㄉㄧㄝˊ", "ㄋㄥˊ", "ㄌㄧㄡˊ", "ㄧˋ", "ㄌㄩˇ", "ㄈㄤ"],
      expected: expectedResponse
    )
  }

  // MARK: Private

  // 於本測試中提供 DSL 風格的共用輔助，減少重複樣板碼
  private func assertCandidateServiceResponse(
    services: [String],
    index: Int,
    candidate: String,
    reading: [String],
    expected: String
  ) {
    let stacked = services.parseIntoCandidateTextServiceStack(
      candidate: candidate,
      reading: reading
    )
    XCTAssertTrue(stacked.indices.contains(index), "Service index out of range.")
    let theService = stacked[index]
    switch theService.value {
    case .url:
      XCTFail("Unexpected URL service at index \(index).")
    case .selector:
      let response = theService.responseFromSelector
      XCTAssertEqual(response, expected)
    }
  }

  private func assertServiceCountReducedAfterFinalSanityCheck(
    services: [String],
    candidate: String,
    reading: [String]
  ) {
    var stacked = services.parseIntoCandidateTextServiceStack(
      candidate: candidate,
      reading: reading
    )
    let count1 = stacked.count
    CandidateTextService.enableFinalSanityCheck()
    stacked = services.parseIntoCandidateTextServiceStack(candidate: candidate, reading: reading)
    let count2 = stacked.count
    XCTAssertGreaterThan(count1, count2)
  }
}
