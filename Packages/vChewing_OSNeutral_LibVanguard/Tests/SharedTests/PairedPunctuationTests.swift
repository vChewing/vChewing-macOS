// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import Shared
import Testing

@Suite("成對標點對照表")
struct PairedPunctuationTests {
  @Test("左右對照表逐項互為反函式")
  func tableIsSymmetric() {
    #expect(PairedPunctuation.leftToRight.count == 29)
    #expect(PairedPunctuation.rightToLeft.count == 29)
    PairedPunctuation.leftToRight.forEach { left, right in
      #expect(PairedPunctuation.rightToLeft[right] == left, "\(left) → \(right)")
      #expect(PairedPunctuation.counterpart(of: left) == right)
      #expect(PairedPunctuation.counterpart(of: right) == left)
    }
  }

  @Test("常見成對標點之對位")
  func knownPairs() {
    let expectations: [String: String] = [
      "「": "」", "『": "』", "【": "】", "〔": "〕", "《": "》", "〈": "〉",
      "（": "）", "“": "”", "‘": "’", "«": "»", "‹": "›", "﹁": "﹂",
      "﹃": "﹄", "︵": "︶", "︽": "︾", "︿": "﹀", "︻": "︼", "︗": "︘",
      "[": "]", "｢": "｣", "{": "}", "(": ")", "<": ">",
    ]
    expectations.forEach { left, right in
      #expect(PairedPunctuation.counterpart(of: left) == right, "\(left) → \(right)")
      #expect(PairedPunctuation.counterpart(of: right) == left, "\(right) → \(left)")
    }
  }

  @Test("完整成對與單邊之判定")
  func fullPairRecognition() {
    #expect(PairedPunctuation.isFullPair("【】"))
    #expect(PairedPunctuation.isFullPair("〈〉"))
    #expect(PairedPunctuation.isFullPair("（）"))
    #expect(PairedPunctuation.isFullPair("︵︶"))
    #expect(PairedPunctuation.isFullPair("[]"))
    #expect(PairedPunctuation.isFullPair("｢｣"))
    #expect(PairedPunctuation.isFullPair("{}"))
    #expect(PairedPunctuation.isFullPair("()"))
    #expect(PairedPunctuation.isFullPair("<>"))
    #expect(!PairedPunctuation.isFullPair("(["))
    #expect(!PairedPunctuation.isFullPair("【"))
    #expect(!PairedPunctuation.isFullPair("】"))
    #expect(!PairedPunctuation.isFullPair("【〕"))
    #expect(!PairedPunctuation.isFullPair("、"))
    #expect(!PairedPunctuation.isFullPair("【】】"))
  }

  @Test("拆對所得之索引鍵")
  func decomposeKeys() {
    let bracket = PairedPunctuation.decompose(fullPair: "【】")
    #expect(bracket?.leftKey == "_punctuation_[")
    #expect(bracket?.leftValue == "【")
    #expect(bracket?.rightKey == "_punctuation_]")
    #expect(bracket?.rightValue == "】")

    let brace = PairedPunctuation.decompose(fullPair: "〈〉")
    #expect(brace?.leftKey == "_punctuation_{")
    #expect(brace?.leftValue == "〈")
    #expect(brace?.rightKey == "_punctuation_}")
    #expect(brace?.rightValue == "〉")

    let paren = PairedPunctuation.decompose(fullPair: "（）")
    #expect(paren?.leftKey == "_punctuation_(")
    #expect(paren?.leftValue == "（")
    #expect(paren?.rightKey == "_punctuation_)")
    #expect(paren?.rightValue == "）")

    let square = PairedPunctuation.decompose(fullPair: "[]")
    #expect(square?.leftKey == "_half_punctuation_[")
    #expect(square?.leftValue == "[")
    #expect(square?.rightKey == "_half_punctuation_]")
    #expect(square?.rightValue == "]")

    let angle = PairedPunctuation.decompose(fullPair: "<>")
    #expect(angle?.leftKey == "_half_punctuation_<")
    #expect(angle?.leftValue == "<")
    #expect(angle?.rightKey == "_half_punctuation_>")
    #expect(angle?.rightValue == ">")

    #expect(PairedPunctuation.decompose(fullPair: "【") == nil)
    #expect(PairedPunctuation.decompose(fullPair: "【〕") == nil)
    #expect(PairedPunctuation.decompose(fullPair: "、") == nil)
  }

  @Test("非成對元件之判定")
  func nonPairComponents() {
    ["、", "＼", "／", "…", "｜", "【】"].forEach { value in
      #expect(!PairedPunctuation.isLeftComponent(value), "\(value)")
      #expect(!PairedPunctuation.isRightComponent(value), "\(value)")
    }
  }
}
