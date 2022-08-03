// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

enum AppleKeyboardConverter {
  static let arrDynamicBasicKeyLayout: [String] = [
    "com.apple.keylayout.ZhuyinBopomofo",
    "com.apple.keylayout.ZhuyinEten",
    "org.atelierInmu.vChewing.keyLayouts.vchewingdachen",
    "org.atelierInmu.vChewing.keyLayouts.vchewingmitac",
    "org.atelierInmu.vChewing.keyLayouts.vchewingibm",
    "org.atelierInmu.vChewing.keyLayouts.vchewingseigyou",
    "org.atelierInmu.vChewing.keyLayouts.vchewingeten",
    "org.unknown.keylayout.vChewingDachen",
    "org.unknown.keylayout.vChewingFakeSeigyou",
    "org.unknown.keylayout.vChewingETen",
    "org.unknown.keylayout.vChewingIBM",
    "org.unknown.keylayout.vChewingMiTAC",
  ]

  static var isDynamicBasicKeyboardLayoutEnabled: Bool {
    AppleKeyboardConverter.arrDynamicBasicKeyLayout.contains(mgrPrefs.basicKeyboardLayout)
  }

  // 處理 Apple 注音鍵盤佈局類型。
  static func cnvApple2ABC(_ charCode: UniChar) -> UniChar {
    var charCode = charCode
    // 在按鍵資訊被送往注拼引擎之前，先轉換為可以被注拼引擎正常處理的資訊。
    if isDynamicBasicKeyboardLayoutEnabled {
      // 針對不同的 Apple 動態鍵盤佈局糾正大寫英文輸入。
      switch mgrPrefs.basicKeyboardLayout {
        case "com.apple.keylayout.ZhuyinBopomofo":
          switch charCode {
            case 97...122: charCode -= 32
            default: break
          }
        case "com.apple.keylayout.ZhuyinEten":
          switch charCode {
            case 65345...65370: charCode -= 65280
            default: break
          }
        default: break
      }
      // 注音鍵群。
      switch charCode {
        case 12573: charCode = UniChar(44)
        case 12582: charCode = UniChar(45)
        case 12577: charCode = UniChar(46)
        case 12581: charCode = UniChar(47)
        case 12578: charCode = UniChar(48)
        case 12549: charCode = UniChar(49)
        case 12553: charCode = UniChar(50)
        case 711: charCode = UniChar(51)
        case 715: charCode = UniChar(52)
        case 12563: charCode = UniChar(53)
        case 714: charCode = UniChar(54)
        case 729: charCode = UniChar(55)
        case 12570: charCode = UniChar(56)
        case 12574: charCode = UniChar(57)
        case 12580: charCode = UniChar(59)
        case 12551: charCode = UniChar(97)
        case 12566: charCode = UniChar(98)
        case 12559: charCode = UniChar(99)
        case 12558: charCode = UniChar(100)
        case 12557: charCode = UniChar(101)
        case 12561: charCode = UniChar(102)
        case 12565: charCode = UniChar(103)
        case 12568: charCode = UniChar(104)
        case 12571: charCode = UniChar(105)
        case 12584: charCode = UniChar(106)
        case 12572: charCode = UniChar(107)
        case 12576: charCode = UniChar(108)
        case 12585: charCode = UniChar(109)
        case 12569: charCode = UniChar(110)
        case 12575: charCode = UniChar(111)
        case 12579: charCode = UniChar(112)
        case 12550: charCode = UniChar(113)
        case 12560: charCode = UniChar(114)
        case 12555: charCode = UniChar(115)
        case 12564: charCode = UniChar(116)
        case 12583: charCode = UniChar(117)
        case 12562: charCode = UniChar(118)
        case 12554: charCode = UniChar(119)
        case 12556: charCode = UniChar(120)
        case 12567: charCode = UniChar(121)
        case 12552: charCode = UniChar(122)
        default: break
      }
      // 除了數字鍵區以外的標點符號。
      switch charCode {
        case 12289: charCode = UniChar(92)
        case 12300: charCode = UniChar(91)
        case 12301: charCode = UniChar(93)
        case 12302: charCode = UniChar(123)
        case 12303: charCode = UniChar(125)
        case 65292: charCode = UniChar(60)
        case 12290: charCode = UniChar(62)
        default: break
      }
      // 摁了 SHIFT 之後的數字區的符號。
      switch charCode {
        case 65281: charCode = UniChar(33)
        case 65312: charCode = UniChar(64)
        case 65283: charCode = UniChar(35)
        case 65284: charCode = UniChar(36)
        case 65285: charCode = UniChar(37)
        case 65087: charCode = UniChar(94)
        case 65286: charCode = UniChar(38)
        case 65290: charCode = UniChar(42)
        case 65288: charCode = UniChar(40)
        case 65289: charCode = UniChar(41)
        default: break
      }
      // 摁了 Alt 的符號。
      if charCode == 8212 { charCode = UniChar(45) }
      // Apple 倚天注音佈局追加符號糾正項目。
      if mgrPrefs.basicKeyboardLayout == "com.apple.keylayout.ZhuyinEten" {
        switch charCode {
          case 65343: charCode = UniChar(95)
          case 65306: charCode = UniChar(58)
          case 65311: charCode = UniChar(63)
          case 65291: charCode = UniChar(43)
          case 65372: charCode = UniChar(124)
          default: break
        }
      }
    }
    return charCode
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
