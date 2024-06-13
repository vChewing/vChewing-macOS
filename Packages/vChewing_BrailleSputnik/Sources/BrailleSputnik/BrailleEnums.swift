// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

extension BrailleSputnik {
  enum Braille: String {
    case blank = "⠀" // U+2800
    case d1 = "⠁"
    case d2 = "⠂"
    case d12 = "⠃"
    case d3 = "⠄"
    case d13 = "⠅"
    case d23 = "⠆"
    case d123 = "⠇"
    case d4 = "⠈"
    case d14 = "⠉"
    case d24 = "⠊"
    case d124 = "⠋"
    case d34 = "⠌"
    case d134 = "⠍"
    case d234 = "⠎"
    case d1234 = "⠏"
    case d5 = "⠐"
    case d15 = "⠑"
    case d25 = "⠒"
    case d125 = "⠓"
    case d35 = "⠔"
    case d135 = "⠕"
    case d235 = "⠖"
    case d1235 = "⠗"
    case d45 = "⠘"
    case d145 = "⠙"
    case d245 = "⠚"
    case d1245 = "⠛"
    case d345 = "⠜"
    case d1345 = "⠝"
    case d2345 = "⠞"
    case d12345 = "⠟"
    case d6 = "⠠"
    case d16 = "⠡"
    case d26 = "⠢"
    case d126 = "⠣"
    case d36 = "⠤"
    case d136 = "⠥"
    case d236 = "⠦"
    case d1236 = "⠧"
    case d46 = "⠨"
    case d146 = "⠩"
    case d246 = "⠪"
    case d1246 = "⠫"
    case d346 = "⠬"
    case d1346 = "⠭"
    case d2346 = "⠮"
    case d12346 = "⠯"
    case d56 = "⠰"
    case d156 = "⠱"
    case d256 = "⠲"
    case d1256 = "⠳"
    case d356 = "⠴"
    case d1356 = "⠵"
    case d2356 = "⠶"
    case d12356 = "⠷"
    case d456 = "⠸"
    case d1456 = "⠹"
    case d2456 = "⠺"
    case d12456 = "⠻"
    case d3456 = "⠼"
    case d13456 = "⠽"
    case d23456 = "⠾"
    case d123456 = "⠿"
  }

  public enum BrailleStandard: Int {
    case of1947 = 1
    case of2018 = 2
  }
}

// MARK: - BrailleProcessingUnit

protocol BrailleProcessingUnit {
  var mapConsonants: [String: String] { get }
  var mapSemivowels: [String: String] { get }
  var mapVowels: [String: String] { get }
  var mapIntonations: [String: String] { get }
  var mapIntonationSpecialCases: [String: String] { get }
  var mapCombinedVowels: [String: String] { get }
  var mapPunctuations: [String: String] { get }

  func handleSpecialCases(target: inout String, value: String?) -> Bool
}

// MARK: - BrailleSputnik.BrailleProcessingUnit1947

extension BrailleSputnik {
  class BrailleProcessingUnit1947: BrailleProcessingUnit {
    let mapConsonants: [String: String] = [
      "ㄎ": "⠇", "ㄋ": "⠝", "ㄕ": "⠊",
      "ㄌ": "⠉", "ㄆ": "⠏", "ㄇ": "⠍",
      "ㄓ": "⠁", "ㄏ": "⠗", "ㄖ": "⠛",
      "ㄅ": "⠕", "ㄑ": "⠚", "ㄘ": "⠚",
      "ㄗ": "⠓", "ㄙ": "⠑", "ㄐ": "⠅",
      "ㄉ": "⠙", "ㄈ": "⠟", "ㄔ": "⠃",
      "ㄒ": "⠑", "ㄊ": "⠋", "ㄍ": "⠅",
    ]

    let mapSemivowels: [String: String] = [
      "ㄧ": "⠡", "ㄩ": "⠳", "ㄨ": "⠌",
    ]

    let mapVowels: [String: String] = [
      "ㄤ": "⠭", "ㄛ": "⠣", "ㄠ": "⠩",
      "ㄞ": "⠺", "ㄜ": "⠮", "ㄡ": "⠷",
      "ㄟ": "⠴", "ㄣ": "⠥", "ㄥ": "⠵",
      "ㄢ": "⠧", "ㄚ": "⠜", "ㄦ": "⠱",
    ]

    let mapIntonations: [String: String] = [
      "˙": "⠱⠁", "ˇ": "⠈", "ˊ": "⠂", " ": "⠄", "ˋ": "⠐",
    ]

    let mapIntonationSpecialCases: [String: String] = [
      "ㄜ˙": "⠮⠁", "ㄚ˙": "⠜⠁", "ㄛ˙": "⠣⠁", "ㄣ˙": "⠥⠁",
    ]

    let mapCombinedVowels: [String: String] = [
      "ㄧㄝ": "⠬", "ㄧㄣ": "⠹", "ㄩㄝ": "⠦",
      "ㄨㄟ": "⠫", "ㄨㄥ": "⠯", "ㄨㄣ": "⠿",
      "ㄨㄚ": "⠔", "ㄧㄡ": "⠎", "ㄧㄤ": "⠨",
      "ㄧㄚ": "⠾", "ㄨㄛ": "⠒", "ㄧㄥ": "⠽",
      "ㄨㄞ": "⠶", "ㄩㄥ": "⠖", "ㄧㄠ": "⠪",
      "ㄧㄞ": "⠢", "ㄨㄤ": "⠸", "ㄩㄣ": "⠲",
      "ㄧㄢ": "⠞", "ㄩㄢ": "⠘", "ㄨㄢ": "⠻",
    ]

    let mapPunctuations: [String: String] = [
      "。": "⠤⠀", "·": "⠤⠀", "，": "⠆", "；": "⠰",
      "、": "⠠", "？": "⠕⠀", "！": "⠇⠀", "：": "⠒⠒",
      "╴╴": "⠰⠰", "﹏﹏": "⠠⠤", "……": "⠐⠐⠐",
      "—": "⠐⠂", "——　——": "⠐⠂⠐⠂", "※": "⠈⠼", "◎": "⠪⠕",
      "『": "⠦⠦", "』": "⠴⠴", "「": "⠰⠤", "」": "⠤⠆",
      "‘": "⠦⠦", "’": "⠴⠴", "“": "⠰⠤", "”": "⠤⠆",
      "（": "⠪", "）": "⠕", "〔": "⠯", "〕": "⠽",
      "｛": "⠦", "｝": "⠴", "［": "⠯", "］": "⠽",
    ]

    func handleSpecialCases(target _: inout String, value _: String?) -> Bool {
      // 國語點字標準無最終例外處理步驟。
      false
    }
  }
}

// MARK: - BrailleSputnik.BrailleProcessingUnit2018

extension BrailleSputnik {
  class BrailleProcessingUnit2018: BrailleProcessingUnit {
    let mapConsonants: [String: String] = [
      "ㄅ": Braille.d12.rawValue,
      "ㄆ": Braille.d1234.rawValue,
      "ㄇ": Braille.d134.rawValue,
      "ㄈ": Braille.d124.rawValue,
      "ㄉ": Braille.d145.rawValue,
      "ㄊ": Braille.d2345.rawValue,
      "ㄋ": Braille.d1345.rawValue,
      "ㄌ": Braille.d123.rawValue,
      "ㄍ": Braille.d1245.rawValue,
      "ㄎ": Braille.d13.rawValue,
      "ㄏ": Braille.d125.rawValue,
      "ㄐ": Braille.d1245.rawValue,
      "ㄑ": Braille.d13.rawValue,
      "ㄒ": Braille.d125.rawValue,
      "ㄓ": Braille.d34.rawValue,
      "ㄔ": Braille.d12345.rawValue,
      "ㄕ": Braille.d156.rawValue,
      "ㄖ": Braille.d245.rawValue,
      "ㄗ": Braille.d1356.rawValue,
      "ㄘ": Braille.d14.rawValue,
      "ㄙ": Braille.d234.rawValue,
    ]

    let mapSemivowels: [String: String] = [
      "ㄧ": Braille.d24.rawValue,
      "ㄨ": Braille.d136.rawValue,
      "ㄩ": Braille.d346.rawValue,
    ]

    let mapVowels: [String: String] = [
      "ㄚ": Braille.d35.rawValue,
      "ㄛ": Braille.d26.rawValue,
      "ㄜ": Braille.d26.rawValue,
      "ㄞ": Braille.d246.rawValue,
      "ㄟ": Braille.d2346.rawValue,
      "ㄠ": Braille.d235.rawValue,
      "ㄡ": Braille.d12356.rawValue,
      "ㄢ": Braille.d1236.rawValue,
      "ㄣ": Braille.d356.rawValue,
      "ㄤ": Braille.d236.rawValue,
      "ㄥ": Braille.d3456.rawValue, // 該注音符號也有合併處理規則。
      "ㄦ": Braille.d1235.rawValue,
    ]

    let mapIntonations: [String: String] = [
      " ": Braille.d1.rawValue,
      "ˊ": Braille.d2.rawValue,
      "ˇ": Braille.d3.rawValue,
      "ˋ": Braille.d23.rawValue,
      // "˙": nil, // 輕聲不設符號。
    ]

    let mapIntonationSpecialCases: [String: String] = [:]

    let mapCombinedVowels: [String: String] = [
      "ㄧㄚ": Braille.d1246.rawValue,
      "ㄧㄝ": Braille.d15.rawValue,
      "ㄧㄞ": Braille.d1246.rawValue, // 此乃特例「崖」，依陸規審音處理。
      "ㄧㄠ": Braille.d345.rawValue,
      "ㄧㄡ": Braille.d1256.rawValue,
      "ㄧㄢ": Braille.d146.rawValue,
      "ㄧㄣ": Braille.d126.rawValue,
      "ㄧㄤ": Braille.d1346.rawValue,
      "ㄧㄥ": Braille.d16.rawValue,
      "ㄨㄚ": Braille.d123456.rawValue,
      "ㄨㄛ": Braille.d135.rawValue,
      "ㄨㄞ": Braille.d13456.rawValue,
      "ㄨㄟ": Braille.d2456.rawValue,
      "ㄨㄢ": Braille.d12456.rawValue,
      "ㄨㄣ": Braille.d25.rawValue,
      "ㄨㄤ": Braille.d2356.rawValue,
      "ㄨㄥ": Braille.d256.rawValue,
      "ㄩㄝ": Braille.d23456.rawValue,
      "ㄩㄢ": Braille.d12346.rawValue,
      "ㄩㄣ": Braille.d456.rawValue,
      "ㄩㄥ": Braille.d1456.rawValue,
    ]

    let mapPunctuations: [String: String] = [
      "。": Braille.d5.rawValue + Braille.d23.rawValue,
      "·": Braille.d6.rawValue + Braille.d3.rawValue,
      "，": Braille.d5.rawValue,
      "；": Braille.d56.rawValue,
      "、": Braille.d4.rawValue,
      "？": Braille.d5.rawValue + Braille.d3.rawValue,
      "！": Braille.d56.rawValue + Braille.d2.rawValue,
      "：": Braille.d36.rawValue,
      "——": Braille.d6.rawValue + Braille.d36.rawValue,
      "……": Braille.d5.rawValue + Braille.d5.rawValue + Braille.d5.rawValue,
      "-": Braille.d36.rawValue,
      "‧": Braille.d5.rawValue, // 著重號。
      "＊": Braille.d2356.rawValue + Braille.d35.rawValue,
      "《": Braille.d5.rawValue + Braille.d36.rawValue,
      "》": Braille.d36.rawValue + Braille.d2.rawValue,
      "〈": Braille.d5.rawValue + Braille.d3.rawValue,
      "〉": Braille.d6.rawValue + Braille.d2.rawValue,
      "『": Braille.d45.rawValue + Braille.d45.rawValue,
      "』": Braille.d45.rawValue + Braille.d45.rawValue,
      "「": Braille.d45.rawValue,
      "」": Braille.d45.rawValue,
      "‘": Braille.d45.rawValue + Braille.d45.rawValue,
      "’": Braille.d45.rawValue + Braille.d45.rawValue,
      "“": Braille.d45.rawValue,
      "”": Braille.d45.rawValue,
      "（": Braille.d56.rawValue + Braille.d3.rawValue,
      "）": Braille.d6.rawValue + Braille.d23.rawValue,
      "〔": Braille.d56.rawValue + Braille.d23.rawValue,
      "〕": Braille.d56.rawValue + Braille.d23.rawValue,
      "［": Braille.d56.rawValue + Braille.d23.rawValue,
      "］": Braille.d56.rawValue + Braille.d23.rawValue,
      // "｛": "⠦", "｝": "⠴", // 2018 國通標準並未定義花括弧。
    ]

    func handleSpecialCases(target: inout String, value: String?) -> Bool {
      guard let value = value else { return false }
      switch value {
      case "他": target = Braille.d2345.rawValue + Braille.d35.rawValue
      case "它": target = Braille.d4.rawValue + Braille.d2345.rawValue + Braille.d35.rawValue
      default: return false
      }
      return true
    }
  }
}
