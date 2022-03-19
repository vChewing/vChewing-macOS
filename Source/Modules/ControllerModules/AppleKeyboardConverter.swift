// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

@objc class AppleKeyboardConverter: NSObject {
    @objc class func isDynamicBaseKeyboardLayoutEnabled() -> Bool {
        switch mgrPrefs.basisKeyboardLayout {
        case "com.apple.keylayout.ZhuyinBopomofo":
            return true
        case "com.apple.keylayout.ZhuyinEten":
            return true
        case "org.atelierInmu.vChewing.keyLayouts.vchewingdachen":
            return true
        case "org.atelierInmu.vChewing.keyLayouts.vchewingmitac":
            return true
        case "org.atelierInmu.vChewing.keyLayouts.vchewingibm":
            return true
        case "org.atelierInmu.vChewing.keyLayouts.vchewingseigyou":
            return true
        case "org.atelierInmu.vChewing.keyLayouts.vchewingeten":
            return true
        default:
            return false
        }
    }
    // 處理 Apple 注音鍵盤佈局類型。
    @objc class func cnvApple2ABC(_ charCode: UniChar) -> UniChar {
        var charCode = charCode
        // 在按鍵資訊被送往 OVMandarin 之前，先轉換為可以被 OVMandarin 正常處理的資訊。
        if self.isDynamicBaseKeyboardLayoutEnabled() {
            // 針對不同的 Apple 動態鍵盤佈局糾正大寫英文輸入。
            switch mgrPrefs.basisKeyboardLayout {
            case "com.apple.keylayout.ZhuyinBopomofo": do {
                if (charCode == 97) {charCode = UniChar(65)}
                if (charCode == 98) {charCode = UniChar(66)}
                if (charCode == 99) {charCode = UniChar(67)}
                if (charCode == 100) {charCode = UniChar(68)}
                if (charCode == 101) {charCode = UniChar(69)}
                if (charCode == 102) {charCode = UniChar(70)}
                if (charCode == 103) {charCode = UniChar(71)}
                if (charCode == 104) {charCode = UniChar(72)}
                if (charCode == 105) {charCode = UniChar(73)}
                if (charCode == 106) {charCode = UniChar(74)}
                if (charCode == 107) {charCode = UniChar(75)}
                if (charCode == 108) {charCode = UniChar(76)}
                if (charCode == 109) {charCode = UniChar(77)}
                if (charCode == 110) {charCode = UniChar(78)}
                if (charCode == 111) {charCode = UniChar(79)}
                if (charCode == 112) {charCode = UniChar(80)}
                if (charCode == 113) {charCode = UniChar(81)}
                if (charCode == 114) {charCode = UniChar(82)}
                if (charCode == 115) {charCode = UniChar(83)}
                if (charCode == 116) {charCode = UniChar(84)}
                if (charCode == 117) {charCode = UniChar(85)}
                if (charCode == 118) {charCode = UniChar(86)}
                if (charCode == 119) {charCode = UniChar(87)}
                if (charCode == 120) {charCode = UniChar(88)}
                if (charCode == 121) {charCode = UniChar(89)}
                if (charCode == 122) {charCode = UniChar(90)}
            }
            case "com.apple.keylayout.ZhuyinEten": do {
                if (charCode == 65345) {charCode = UniChar(65)}
                if (charCode == 65346) {charCode = UniChar(66)}
                if (charCode == 65347) {charCode = UniChar(67)}
                if (charCode == 65348) {charCode = UniChar(68)}
                if (charCode == 65349) {charCode = UniChar(69)}
                if (charCode == 65350) {charCode = UniChar(70)}
                if (charCode == 65351) {charCode = UniChar(71)}
                if (charCode == 65352) {charCode = UniChar(72)}
                if (charCode == 65353) {charCode = UniChar(73)}
                if (charCode == 65354) {charCode = UniChar(74)}
                if (charCode == 65355) {charCode = UniChar(75)}
                if (charCode == 65356) {charCode = UniChar(76)}
                if (charCode == 65357) {charCode = UniChar(77)}
                if (charCode == 65358) {charCode = UniChar(78)}
                if (charCode == 65359) {charCode = UniChar(79)}
                if (charCode == 65360) {charCode = UniChar(80)}
                if (charCode == 65361) {charCode = UniChar(81)}
                if (charCode == 65362) {charCode = UniChar(82)}
                if (charCode == 65363) {charCode = UniChar(83)}
                if (charCode == 65364) {charCode = UniChar(84)}
                if (charCode == 65365) {charCode = UniChar(85)}
                if (charCode == 65366) {charCode = UniChar(86)}
                if (charCode == 65367) {charCode = UniChar(87)}
                if (charCode == 65368) {charCode = UniChar(88)}
                if (charCode == 65369) {charCode = UniChar(89)}
                if (charCode == 65370) {charCode = UniChar(90)}
            }
            default: break
            }
            // 注音鍵群。
            if (charCode == 12573) {charCode = UniChar(44)}
            if (charCode == 12582) {charCode = UniChar(45)}
            if (charCode == 12577) {charCode = UniChar(46)}
            if (charCode == 12581) {charCode = UniChar(47)}
            if (charCode == 12578) {charCode = UniChar(48)}
            if (charCode == 12549) {charCode = UniChar(49)}
            if (charCode == 12553) {charCode = UniChar(50)}
            if (charCode == 711) {charCode = UniChar(51)}
            if (charCode == 715) {charCode = UniChar(52)}
            if (charCode == 12563) {charCode = UniChar(53)}
            if (charCode == 714) {charCode = UniChar(54)}
            if (charCode == 729) {charCode = UniChar(55)}
            if (charCode == 12570) {charCode = UniChar(56)}
            if (charCode == 12574) {charCode = UniChar(57)}
            if (charCode == 12580) {charCode = UniChar(59)}
            if (charCode == 12551) {charCode = UniChar(97)}
            if (charCode == 12566) {charCode = UniChar(98)}
            if (charCode == 12559) {charCode = UniChar(99)}
            if (charCode == 12558) {charCode = UniChar(100)}
            if (charCode == 12557) {charCode = UniChar(101)}
            if (charCode == 12561) {charCode = UniChar(102)}
            if (charCode == 12565) {charCode = UniChar(103)}
            if (charCode == 12568) {charCode = UniChar(104)}
            if (charCode == 12571) {charCode = UniChar(105)}
            if (charCode == 12584) {charCode = UniChar(106)}
            if (charCode == 12572) {charCode = UniChar(107)}
            if (charCode == 12576) {charCode = UniChar(108)}
            if (charCode == 12585) {charCode = UniChar(109)}
            if (charCode == 12569) {charCode = UniChar(110)}
            if (charCode == 12575) {charCode = UniChar(111)}
            if (charCode == 12579) {charCode = UniChar(112)}
            if (charCode == 12550) {charCode = UniChar(113)}
            if (charCode == 12560) {charCode = UniChar(114)}
            if (charCode == 12555) {charCode = UniChar(115)}
            if (charCode == 12564) {charCode = UniChar(116)}
            if (charCode == 12583) {charCode = UniChar(117)}
            if (charCode == 12562) {charCode = UniChar(118)}
            if (charCode == 12554) {charCode = UniChar(119)}
            if (charCode == 12556) {charCode = UniChar(120)}
            if (charCode == 12567) {charCode = UniChar(121)}
            if (charCode == 12552) {charCode = UniChar(122)}
            // 除了數字鍵區以外的標點符號。
            if (charCode == 12289) {charCode = UniChar(92)}
            if (charCode == 12300) {charCode = UniChar(91)}
            if (charCode == 12301) {charCode = UniChar(93)}
            if (charCode == 12302) {charCode = UniChar(123)}
            if (charCode == 12303) {charCode = UniChar(125)}
            if (charCode == 65292) {charCode = UniChar(60)}
            if (charCode == 12290) {charCode = UniChar(62)}
            // 摁了 SHIFT 之後的數字區的符號。
            if (charCode == 65281) {charCode = UniChar(33)}
            if (charCode == 65312) {charCode = UniChar(64)}
            if (charCode == 65283) {charCode = UniChar(35)}
            if (charCode == 65284) {charCode = UniChar(36)}
            if (charCode == 65285) {charCode = UniChar(37)}
            if (charCode == 65087) {charCode = UniChar(94)}
            if (charCode == 65286) {charCode = UniChar(38)}
            if (charCode == 65290) {charCode = UniChar(42)}
            if (charCode == 65288) {charCode = UniChar(40)}
            if (charCode == 65289) {charCode = UniChar(41)}
            // Apple 倚天注音佈局追加符號糾正項目。
            if mgrPrefs.basisKeyboardLayout == "com.apple.keylayout.ZhuyinEten" {
                if (charCode == 65343) {charCode = UniChar(95)}
                if (charCode == 65306) {charCode = UniChar(58)}
                if (charCode == 65311) {charCode = UniChar(63)}
                if (charCode == 65291) {charCode = UniChar(43)}
                if (charCode == 65372) {charCode = UniChar(124)}
            }
        }
        return charCode
    }

    @objc class func cnvStringApple2ABC(_ strProcessed: String) -> String {
        var strProcessed = strProcessed
        if self.isDynamicBaseKeyboardLayoutEnabled() {
            // 針對不同的 Apple 動態鍵盤佈局糾正大寫英文輸入。
            switch mgrPrefs.basisKeyboardLayout {
            case "com.apple.keylayout.ZhuyinBopomofo": do {
                if (strProcessed == "a") {strProcessed = "A"}
                if (strProcessed == "b") {strProcessed = "B"}
                if (strProcessed == "c") {strProcessed = "C"}
                if (strProcessed == "d") {strProcessed = "D"}
                if (strProcessed == "e") {strProcessed = "E"}
                if (strProcessed == "f") {strProcessed = "F"}
                if (strProcessed == "g") {strProcessed = "G"}
                if (strProcessed == "h") {strProcessed = "H"}
                if (strProcessed == "i") {strProcessed = "I"}
                if (strProcessed == "j") {strProcessed = "J"}
                if (strProcessed == "k") {strProcessed = "K"}
                if (strProcessed == "l") {strProcessed = "L"}
                if (strProcessed == "m") {strProcessed = "M"}
                if (strProcessed == "n") {strProcessed = "N"}
                if (strProcessed == "o") {strProcessed = "O"}
                if (strProcessed == "p") {strProcessed = "P"}
                if (strProcessed == "q") {strProcessed = "Q"}
                if (strProcessed == "r") {strProcessed = "R"}
                if (strProcessed == "s") {strProcessed = "S"}
                if (strProcessed == "t") {strProcessed = "T"}
                if (strProcessed == "u") {strProcessed = "U"}
                if (strProcessed == "v") {strProcessed = "V"}
                if (strProcessed == "w") {strProcessed = "W"}
                if (strProcessed == "x") {strProcessed = "X"}
                if (strProcessed == "y") {strProcessed = "Y"}
                if (strProcessed == "z") {strProcessed = "Z"}
            }
            case "com.apple.keylayout.ZhuyinEten": do {
                if (strProcessed == "ａ") {strProcessed = "A"}
                if (strProcessed == "ｂ") {strProcessed = "B"}
                if (strProcessed == "ｃ") {strProcessed = "C"}
                if (strProcessed == "ｄ") {strProcessed = "D"}
                if (strProcessed == "ｅ") {strProcessed = "E"}
                if (strProcessed == "ｆ") {strProcessed = "F"}
                if (strProcessed == "ｇ") {strProcessed = "G"}
                if (strProcessed == "ｈ") {strProcessed = "H"}
                if (strProcessed == "ｉ") {strProcessed = "I"}
                if (strProcessed == "ｊ") {strProcessed = "J"}
                if (strProcessed == "ｋ") {strProcessed = "K"}
                if (strProcessed == "ｌ") {strProcessed = "L"}
                if (strProcessed == "ｍ") {strProcessed = "M"}
                if (strProcessed == "ｎ") {strProcessed = "N"}
                if (strProcessed == "ｏ") {strProcessed = "O"}
                if (strProcessed == "ｐ") {strProcessed = "P"}
                if (strProcessed == "ｑ") {strProcessed = "Q"}
                if (strProcessed == "ｒ") {strProcessed = "R"}
                if (strProcessed == "ｓ") {strProcessed = "S"}
                if (strProcessed == "ｔ") {strProcessed = "T"}
                if (strProcessed == "ｕ") {strProcessed = "U"}
                if (strProcessed == "ｖ") {strProcessed = "V"}
                if (strProcessed == "ｗ") {strProcessed = "W"}
                if (strProcessed == "ｘ") {strProcessed = "X"}
                if (strProcessed == "ｙ") {strProcessed = "Y"}
                if (strProcessed == "ｚ") {strProcessed = "Z"}
            }
            default: break
            }
            // 注音鍵群。
            if (strProcessed == "ㄝ") {strProcessed = ","}
            if (strProcessed == "ㄦ") {strProcessed = "-"}
            if (strProcessed == "ㄡ") {strProcessed = "."}
            if (strProcessed == "ㄥ") {strProcessed = "/"}
            if (strProcessed == "ㄢ") {strProcessed = "0"}
            if (strProcessed == "ㄅ") {strProcessed = "1"}
            if (strProcessed == "ㄉ") {strProcessed = "2"}
            if (strProcessed == "ˇ") {strProcessed = "3"}
            if (strProcessed == "ˋ") {strProcessed = "4"}
            if (strProcessed == "ㄓ") {strProcessed = "5"}
            if (strProcessed == "ˊ") {strProcessed = "6"}
            if (strProcessed == "˙") {strProcessed = "7"}
            if (strProcessed == "ㄚ") {strProcessed = "8"}
            if (strProcessed == "ㄞ") {strProcessed = "9"}
            if (strProcessed == "ㄤ") {strProcessed = ";"}
            if (strProcessed == "ㄇ") {strProcessed = "a"}
            if (strProcessed == "ㄖ") {strProcessed = "b"}
            if (strProcessed == "ㄏ") {strProcessed = "c"}
            if (strProcessed == "ㄎ") {strProcessed = "d"}
            if (strProcessed == "ㄍ") {strProcessed = "e"}
            if (strProcessed == "ㄑ") {strProcessed = "f"}
            if (strProcessed == "ㄕ") {strProcessed = "g"}
            if (strProcessed == "ㄘ") {strProcessed = "h"}
            if (strProcessed == "ㄛ") {strProcessed = "i"}
            if (strProcessed == "ㄨ") {strProcessed = "j"}
            if (strProcessed == "ㄜ") {strProcessed = "k"}
            if (strProcessed == "ㄠ") {strProcessed = "l"}
            if (strProcessed == "ㄩ") {strProcessed = "m"}
            if (strProcessed == "ㄙ") {strProcessed = "n"}
            if (strProcessed == "ㄟ") {strProcessed = "o"}
            if (strProcessed == "ㄣ") {strProcessed = "p"}
            if (strProcessed == "ㄆ") {strProcessed = "q"}
            if (strProcessed == "ㄐ") {strProcessed = "r"}
            if (strProcessed == "ㄋ") {strProcessed = "s"}
            if (strProcessed == "ㄔ") {strProcessed = "t"}
            if (strProcessed == "ㄧ") {strProcessed = "u"}
            if (strProcessed == "ㄒ") {strProcessed = "v"}
            if (strProcessed == "ㄊ") {strProcessed = "w"}
            if (strProcessed == "ㄌ") {strProcessed = "x"}
            if (strProcessed == "ㄗ") {strProcessed = "y"}
            if (strProcessed == "ㄈ") {strProcessed = "z"}
            // 除了數字鍵區以外的標點符號。
            if (strProcessed == "、") {strProcessed = "\\"}
            if (strProcessed == "「") {strProcessed = "["}
            if (strProcessed == "」") {strProcessed = "]"}
            if (strProcessed == "『") {strProcessed = "{"}
            if (strProcessed == "』") {strProcessed = "}"}
            if (strProcessed == "，") {strProcessed = "<"}
            if (strProcessed == "。") {strProcessed = ">"}
            // 摁了 SHIFT 之後的數字區的符號。
            if (strProcessed == "！") {strProcessed = "!"}
            if (strProcessed == "＠") {strProcessed = "@"}
            if (strProcessed == "＃") {strProcessed = "#"}
            if (strProcessed == "＄") {strProcessed = "$"}
            if (strProcessed == "％") {strProcessed = "%"}
            if (strProcessed == "︿") {strProcessed = "^"}
            if (strProcessed == "＆") {strProcessed = "&"}
            if (strProcessed == "＊") {strProcessed = "*"}
            if (strProcessed == "（") {strProcessed = "("}
            if (strProcessed == "）") {strProcessed = ")"}
            // Apple 倚天注音佈局追加符號糾正項目。
            if mgrPrefs.basisKeyboardLayout == "com.apple.keylayout.ZhuyinEten" {
                if (strProcessed == "＿") {strProcessed = "_"}
                if (strProcessed == "：") {strProcessed = ":"}
                if (strProcessed == "？") {strProcessed = "?"}
                if (strProcessed == "＋") {strProcessed = "+"}
                if (strProcessed == "｜") {strProcessed = "|"}
            }
        }
        return strProcessed
    }
}
