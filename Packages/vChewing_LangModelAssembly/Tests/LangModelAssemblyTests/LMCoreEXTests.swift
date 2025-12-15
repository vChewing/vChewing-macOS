// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// StringView Ranges extension by (c) 2022 and onwards Isaac Xen (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import XCTest

@testable import LangModelAssembly

private let sampleData: String = #"""
#
# 下述詞頻資料取自 libTaBE 資料庫 (http://sourceforge.net/projects/libtabe/)
# (2002 最終版). 該專案於 1999 年由 Pai-Hsiang Hsiao 發起、以 BSD 授權發行。
#
ㄍㄠ 篙 -13.624335
ㄍㄠ 糕 -12.390804
ㄍㄠ 膏 -11.928720
ㄍㄠ 高 -7.171551
ㄎㄜ 刻 -10.450457
ㄎㄜ 柯 -99.000000
ㄎㄜ 棵 -11.504072
ㄎㄜ 科 -7.171052
ㄎㄜ 顆 -10.574273
ㄙ 司 -99.000000
ㄙ 嘶 -13.513987
ㄙ 思 -9.006414
ㄙ 撕 -12.259095
ㄙ 斯 -8.091803
ㄙ 絲 -9.495858
ㄙ 私 -99.000000

"""#

// MARK: - LMCoreEXTests

final class LMCoreEXTests: XCTestCase {
  func testLMCoreEXAsFactoryCoreDict() throws {
    var lmTest = LMAssembly.LMCoreEX(
      reverse: false,
      consolidate: false,
      defaultScore: { _ in 0 },
      forceDefaultScore: false
    )
    lmTest.replaceData(textData: sampleData)
    XCTAssertEqual(lmTest.count, 3)
    let gao1 = lmTest.unigramsFor(key: "ㄍㄠ").map(\.value)
    let ke1 = lmTest.unigramsFor(key: "ㄎㄜ").map(\.value)
    let si1 = lmTest.unigramsFor(key: "ㄙ").map(\.value)
    XCTAssertEqual(gao1, ["篙", "糕", "膏", "高"])
    XCTAssertEqual(ke1, ["刻", "柯", "棵", "科", "顆"])
    XCTAssertEqual(si1, ["司", "嘶", "思", "撕", "斯", "絲", "私"])
  }
}
