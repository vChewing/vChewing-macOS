// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

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

  // ?????? Apple ???????????????????????????
  static func cnvApple2ABC(_ charCode: UniChar) -> UniChar {
    var charCode = charCode
    // ??????????????????????????????????????????????????????????????????????????????????????????????????????
    if isDynamicBasicKeyboardLayoutEnabled {
      // ??????????????? Apple ?????????????????????????????????????????????
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
      // ???????????????
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
      // ??????????????????????????????????????????
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
      // ?????? SHIFT ??????????????????????????????
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
      // ?????? Alt ????????????
      if charCode == 8212 { charCode = UniChar(45) }
      // Apple ?????????????????????????????????????????????
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
      // ??????????????? Apple ?????????????????????????????????????????????
      switch mgrPrefs.basicKeyboardLayout {
        case "com.apple.keylayout.ZhuyinBopomofo":
          if strProcessed.count == 1, Character(strProcessed).isLowercase, Character(strProcessed).isASCII {
            strProcessed = strProcessed.uppercased()
          }
        case "com.apple.keylayout.ZhuyinEten":
          switch strProcessed {
            case "???": strProcessed = "A"
            case "???": strProcessed = "B"
            case "???": strProcessed = "C"
            case "???": strProcessed = "D"
            case "???": strProcessed = "E"
            case "???": strProcessed = "F"
            case "???": strProcessed = "G"
            case "???": strProcessed = "H"
            case "???": strProcessed = "I"
            case "???": strProcessed = "J"
            case "???": strProcessed = "K"
            case "???": strProcessed = "L"
            case "???": strProcessed = "M"
            case "???": strProcessed = "N"
            case "???": strProcessed = "O"
            case "???": strProcessed = "P"
            case "???": strProcessed = "Q"
            case "???": strProcessed = "R"
            case "???": strProcessed = "S"
            case "???": strProcessed = "T"
            case "???": strProcessed = "U"
            case "???": strProcessed = "V"
            case "???": strProcessed = "W"
            case "???": strProcessed = "X"
            case "???": strProcessed = "Y"
            case "???": strProcessed = "Z"
            default: break
          }
        default: break
      }
      // ???????????????
      switch strProcessed {
        case "???": strProcessed = ","
        case "???": strProcessed = "-"
        case "???": strProcessed = "."
        case "???": strProcessed = "/"
        case "???": strProcessed = "0"
        case "???": strProcessed = "1"
        case "???": strProcessed = "2"
        case "??": strProcessed = "3"
        case "??": strProcessed = "4"
        case "???": strProcessed = "5"
        case "??": strProcessed = "6"
        case "??": strProcessed = "7"
        case "???": strProcessed = "8"
        case "???": strProcessed = "9"
        case "???": strProcessed = ";"
        case "???": strProcessed = "a"
        case "???": strProcessed = "b"
        case "???": strProcessed = "c"
        case "???": strProcessed = "d"
        case "???": strProcessed = "e"
        case "???": strProcessed = "f"
        case "???": strProcessed = "g"
        case "???": strProcessed = "h"
        case "???": strProcessed = "i"
        case "???": strProcessed = "j"
        case "???": strProcessed = "k"
        case "???": strProcessed = "l"
        case "???": strProcessed = "m"
        case "???": strProcessed = "n"
        case "???": strProcessed = "o"
        case "???": strProcessed = "p"
        case "???": strProcessed = "q"
        case "???": strProcessed = "r"
        case "???": strProcessed = "s"
        case "???": strProcessed = "t"
        case "???": strProcessed = "u"
        case "???": strProcessed = "v"
        case "???": strProcessed = "w"
        case "???": strProcessed = "x"
        case "???": strProcessed = "y"
        case "???": strProcessed = "z"
        default: break
      }
      // ??????????????????????????????????????????
      switch strProcessed {
        case "???": strProcessed = "\\"
        case "???": strProcessed = "["
        case "???": strProcessed = "]"
        case "???": strProcessed = "{"
        case "???": strProcessed = "}"
        case "???": strProcessed = "<"
        case "???": strProcessed = ">"
        default: break
      }
      // ?????? SHIFT ??????????????????????????????
      switch strProcessed {
        case "???": strProcessed = "!"
        case "???": strProcessed = "@"
        case "???": strProcessed = "#"
        case "???": strProcessed = "$"
        case "???": strProcessed = "%"
        case "???": strProcessed = "^"
        case "???": strProcessed = "&"
        case "???": strProcessed = "*"
        case "???": strProcessed = "("
        case "???": strProcessed = ")"
        default: break
      }
      // ?????? Alt ????????????
      if strProcessed == "???" { strProcessed = "-" }
      // Apple ?????????????????????????????????????????????
      if mgrPrefs.basicKeyboardLayout == "com.apple.keylayout.ZhuyinEten" {
        switch strProcessed {
          case "???": strProcessed = "_"
          case "???": strProcessed = ":"
          case "???": strProcessed = "?"
          case "???": strProcessed = "+"
          case "???": strProcessed = "|"
          default: break
        }
      }
    }
    return strProcessed
  }
}
