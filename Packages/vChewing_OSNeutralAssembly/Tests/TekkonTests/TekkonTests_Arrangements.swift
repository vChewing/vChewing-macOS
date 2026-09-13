// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import Tekkon

// MARK: - Something Else

extension StringProtocol {
  /// 分析傳入的原始辭典檔案（UTF-8 TXT）的資料。
  /// - Parameters:
  ///   - separator: 行內單元分隔符。
  ///   - task: 要執行的外包任務。
  func parse(
    splitee separator: Element,
    task: @escaping (_ theRange: Range<String.Index>) -> ()
  ) {
    var startIndex = startIndex
    split(separator: separator).forEach { substring in
      let theRange = range(of: substring, range: startIndex ..< endIndex)
      guard let theRange else { return }
      task(theRange)
      startIndex = theRange.upperBound
    }
  }
}

extension Tekkon.MandarinParser {
  public init?(nameTag: String) {
    let matched = Self.allCases.first { $0.nameTag == nameTag }
    guard let matched else { return nil }
    self = matched
  }
}

// MARK: - SubTestCase

final class SubTestCase: Sendable {
  // MARK: Lifecycle

  init?(
    parser: Tekkon.MandarinParser,
    typing: any StringProtocol,
    expected: any StringProtocol
  ) {
    guard typing.first != "`" else { return nil }
    self.typing = typing.replacingOccurrences(of: "_", with: " ")
    self.expected = expected.replacingOccurrences(of: "_", with: " ")
    self.parser = parser
  }

  // MARK: Internal

  let parser: Tekkon.MandarinParser
  let typing: String
  let expected: String

  func verify() -> Bool {
    var composer = Tekkon.Composer(arrange: parser)
    let strResult = composer.receiveSequence(typing)
    guard strResult != expected else { return true }
    let parserTag = composer.parser.nameTag
    let strError =
      "MISMATCH (\(parserTag)): \"\(typing)\" -> \"\(strResult)\" != \"\(expected)\""
    print(strError)
    return false
  }

  /// 優化版驗證函數，重複使用已建立的 composer 副本
  func verify(using composer: inout Tekkon.Composer) -> Bool {
    composer.clear()
    composer.ensureParser(arrange: parser)
    let strResult = composer.receiveSequence(typing)
    guard strResult != expected else { return true }
    let parserTag = composer.parser.nameTag
    let strError =
      "MISMATCH (\(parserTag)): \"\(typing)\" -> \"\(strResult)\" != \"\(expected)\""
    print(strError)
    return false
  }
}

// MARK: - TestCaseBatch

/// 批量測試案例處理器，用於減少記憶體分配
actor TestCaseBatch {
  // MARK: Lifecycle

  init(parser: Tekkon.MandarinParser, rawData: String) {
    self.parser = parser
    var cases: [(String, String)] = []
    var isTitleLine = true
    let parserIndex = Self.getParserIndex(parser)

    rawData.parse(splitee: "\n") { theRange in
      guard !isTitleLine else {
        isTitleLine = false
        return
      }
      let cells = rawData[theRange].split(separator: " ")
      guard cells.count > parserIndex else { return }
      let expected = cells[0].replacingOccurrences(of: "_", with: " ")
      let typing = cells[parserIndex].description.replacingOccurrences(of: "_", with: " ")
      guard typing.first != "`" else { return }
      cases.append((typing: typing, expected: expected))
    }
    self.testData = cases
  }

  // MARK: Internal

  let parser: Tekkon.MandarinParser
  let testData: [(typing: String, expected: String)]

  func runTests() async -> Int {
    let indices = testData.indices
    let chunkSize = 350
    let failedCount = await withTaskGroup(of: Int.self, returning: Int.self) { group in
      var failures = 0
      for chunkStartPoint in stride(from: 0, to: indices.upperBound, by: chunkSize) {
        let subIndiceMax = Swift.min(indices.upperBound, chunkStartPoint + chunkSize)
        let subIndices = chunkStartPoint ..< subIndiceMax
        for i in subIndices {
          group.addTask {
            var subFailures = 0
            var composer = Tekkon.Composer(arrange: self.parser)
            let strResult = composer.receiveSequence(self.testData[i].typing)
            if strResult != self.testData[i].expected {
              let parserTag = composer.parser.nameTag
              let typingStr = self.testData[i].typing
              let expectedStr = self.testData[i].expected
              let strError =
                "MISMATCH (\(parserTag)): \"\(typingStr)\" -> \"\(strResult)\" != \"\(expectedStr)\""
              print(strError)
              subFailures += 1
            }
            return subFailures
          }
        }
        for await subFailures in group {
          // Set operation name as key and operation result as value
          failures += subFailures
        }
      }
      return failures
    }
    return failedCount
  }

  // MARK: Private

  private static func getParserIndex(_ parser: Tekkon.MandarinParser) -> Int {
    switch parser {
    case .ofDachen26: return 1
    case .ofETen26: return 2
    case .ofHsu: return 3
    case .ofStarlight: return 4
    case .ofAlvinLiu: return 5
    default: return 1
    }
  }
}

// MARK: - TekkonTestsKeyboardArrangmentsStatic

@MainActor
@Suite(.serialized)
struct TekkonTestsKeyboardArrangmentsStatic {
  static func checkEq(
    _ counter: inout Int,
    _ composer: inout Tekkon.Composer,
    _ strGivenSeq: some StringProtocol,
    _ strExpected: some StringProtocol
  ) {
    let strResult = composer.receiveSequence(strGivenSeq.description)
    guard strResult != strExpected else { return }
    let parserTag = composer.parser.nameTag
    let strError =
      "MISMATCH (\(parserTag)): \"\(strGivenSeq)\" -> \"\(strResult)\" != \"\(strExpected)\""
    print(strError)
    counter += 1
  }

  @Test("[Tekkon] StaticKeyLayout_Dachen")
  func testQwertyDachenKeys() async throws {
    // Testing Dachen Traditional Mapping (QWERTY)
    var c = Tekkon.Composer(arrange: .ofDachen)
    var counter = 0
    Self.checkEq(&counter, &c, " ", " ")
    Self.checkEq(&counter, &c, "18 ", "ㄅㄚ ")
    Self.checkEq(&counter, &c, "m,4", "ㄩㄝˋ")
    Self.checkEq(&counter, &c, "5j/ ", "ㄓㄨㄥ ")
    Self.checkEq(&counter, &c, "fu.", "ㄑㄧㄡ")
    Self.checkEq(&counter, &c, "g0 ", "ㄕㄢ ")
    Self.checkEq(&counter, &c, "xup6", "ㄌㄧㄣˊ")
    Self.checkEq(&counter, &c, "xu;6", "ㄌㄧㄤˊ")
    Self.checkEq(&counter, &c, "z/", "ㄈㄥ")
    Self.checkEq(&counter, &c, "tjo ", "ㄔㄨㄟ ")
    Self.checkEq(&counter, &c, "284", "ㄉㄚˋ")
    Self.checkEq(&counter, &c, "2u4", "ㄉㄧˋ")
    Self.checkEq(&counter, &c, "hl3", "ㄘㄠˇ")
    Self.checkEq(&counter, &c, "5 ", "ㄓ ")
    Self.checkEq(&counter, &c, "193", "ㄅㄞˇ")
    #expect(counter == 0)
  }
}

// MARK: - TekkonTestsKeyboardArrangmentsDynamic

@MainActor
@Suite(.serialized)
struct TekkonTestsKeyboardArrangmentsDynamic {
  typealias Parser = Tekkon.MandarinParser

  @Test(
    "[Tekkon] DynamicKeyLayouts",
    arguments: Array(Parser.allCases.filter(\.isDynamic).enumerated())
  )
  func testDynamicKeyLayouts(
    _ parserEnumerated: EnumeratedSequence<[Parser]>
      .Element
  ) async throws {
    let parser = parserEnumerated.element
    print(" -> [Tekkon] Preparing tests for dynamic keyboard handling...")

    // 使用批量處理器以提升效能
    let testBatch = TestCaseBatch(parser: parser, rawData: testTable4DynamicLayouts)

    let timeTag = Date.now
    print(" -> [Tekkon][(\(parser.nameTag))] Starting dynamic keyboard handling test ...")

    let failures = await testBatch.runTests()

    #expect(
      failures == 0,
      "[Failure] \(parser.nameTag) failed from being handled correctly with \(failures) bad results."
    )
    let timeDelta = Date.now.timeIntervalSince1970 - timeTag.timeIntervalSince1970
    let timeDeltaStr = String(format: "%.4f", timeDelta)
    print(
      " -> [Tekkon][(\(parser.nameTag))] Finished within \(timeDeltaStr) seconds."
    )
  }
}
