// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

enum AppleKeyboardConverter {
  static var isDynamicBasicKeyboardLayoutEnabled: Bool {
    IMKHelper.arrDynamicBasicKeyLayouts.contains(mgrPrefs.basicKeyboardLayout)
  }

  static func cnvStringApple2ABC(_ strProcessed: String) -> String {
    var strProcessed = strProcessed
    if isDynamicBasicKeyboardLayoutEnabled {
      // 針對不同的 Apple 動態鍵盤佈局糾正大寫英文輸入。
      switch mgrPrefs.basicKeyboardLayout {
        case "com.apple.keylayout.ZhuyinBopomofo":
          if strProcessed.count == 1, Character(strProcessed).isLowercase, Character(strProcessed).isASCII {
            strProcessed = strProcessed.uppercased()
          }
        case "com.apple.keylayout.ZhuyinEten":
          switch strProcessed {
            case "ａ": strProcessed = "A"
            case "ｂ": strProcessed = "B"
            case "ｃ": strProcessed = "C"
            case "ｄ": strProcessed = "D"
            case "ｅ": strProcessed = "E"
            case "ｆ": strProcessed = "F"
            case "ｇ": strProcessed = "G"
            case "ｈ": strProcessed = "H"
            case "ｉ": strProcessed = "I"
            case "ｊ": strProcessed = "J"
            case "ｋ": strProcessed = "K"
            case "ｌ": strProcessed = "L"
            case "ｍ": strProcessed = "M"
            case "ｎ": strProcessed = "N"
            case "ｏ": strProcessed = "O"
            case "ｐ": strProcessed = "P"
            case "ｑ": strProcessed = "Q"
            case "ｒ": strProcessed = "R"
            case "ｓ": strProcessed = "S"
            case "ｔ": strProcessed = "T"
            case "ｕ": strProcessed = "U"
            case "ｖ": strProcessed = "V"
            case "ｗ": strProcessed = "W"
            case "ｘ": strProcessed = "X"
            case "ｙ": strProcessed = "Y"
            case "ｚ": strProcessed = "Z"
            default: break
          }
        default: break
      }
      // 注音鍵群。
      switch strProcessed {
        case "ㄝ": strProcessed = ","
        case "ㄦ": strProcessed = "-"
        case "ㄡ": strProcessed = "."
        case "ㄥ": strProcessed = "/"
        case "ㄢ": strProcessed = "0"
        case "ㄅ": strProcessed = "1"
        case "ㄉ": strProcessed = "2"
        case "ˇ": strProcessed = "3"
        case "ˋ": strProcessed = "4"
        case "ㄓ": strProcessed = "5"
        case "ˊ": strProcessed = "6"
        case "˙": strProcessed = "7"
        case "ㄚ": strProcessed = "8"
        case "ㄞ": strProcessed = "9"
        case "ㄤ": strProcessed = ";"
        case "ㄇ": strProcessed = "a"
        case "ㄖ": strProcessed = "b"
        case "ㄏ": strProcessed = "c"
        case "ㄎ": strProcessed = "d"
        case "ㄍ": strProcessed = "e"
        case "ㄑ": strProcessed = "f"
        case "ㄕ": strProcessed = "g"
        case "ㄘ": strProcessed = "h"
        case "ㄛ": strProcessed = "i"
        case "ㄨ": strProcessed = "j"
        case "ㄜ": strProcessed = "k"
        case "ㄠ": strProcessed = "l"
        case "ㄩ": strProcessed = "m"
        case "ㄙ": strProcessed = "n"
        case "ㄟ": strProcessed = "o"
        case "ㄣ": strProcessed = "p"
        case "ㄆ": strProcessed = "q"
        case "ㄐ": strProcessed = "r"
        case "ㄋ": strProcessed = "s"
        case "ㄔ": strProcessed = "t"
        case "ㄧ": strProcessed = "u"
        case "ㄒ": strProcessed = "v"
        case "ㄊ": strProcessed = "w"
        case "ㄌ": strProcessed = "x"
        case "ㄗ": strProcessed = "y"
        case "ㄈ": strProcessed = "z"
        default: break
      }
      // 除了數字鍵區以外的標點符號。
      switch strProcessed {
        case "、": strProcessed = "\\"
        case "「": strProcessed = "["
        case "」": strProcessed = "]"
        case "『": strProcessed = "{"
        case "』": strProcessed = "}"
        case "，": strProcessed = "<"
        case "。": strProcessed = ">"
        default: break
      }
      // 摁了 SHIFT 之後的數字區的符號。
      switch strProcessed {
        case "！": strProcessed = "!"
        case "＠": strProcessed = "@"
        case "＃": strProcessed = "#"
        case "＄": strProcessed = "$"
        case "％": strProcessed = "%"
        case "︿": strProcessed = "^"
        case "＆": strProcessed = "&"
        case "＊": strProcessed = "*"
        case "（": strProcessed = "("
        case "）": strProcessed = ")"
        default: break
      }
      // 摁了 Alt 的符號。
      if strProcessed == "—" { strProcessed = "-" }
      // Apple 倚天注音佈局追加符號糾正項目。
      if mgrPrefs.basicKeyboardLayout == "com.apple.keylayout.ZhuyinEten" {
        switch strProcessed {
          case "＿": strProcessed = "_"
          case "：": strProcessed = ":"
          case "？": strProcessed = "?"
          case "＋": strProcessed = "+"
          case "｜": strProcessed = "|"
          default: break
        }
      }
    }
    return strProcessed
  }
}
