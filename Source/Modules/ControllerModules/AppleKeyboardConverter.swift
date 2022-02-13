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
        switch Preferences.basisKeyboardLayout {
        case "com.apple.keylayout.ZhuyinBopomofo":
            return true
        case "com.apple.keylayout.ZhuyinEten":
            return true
        default:
            return false
        }
    }
    // 處理 Apple 注音鍵盤佈局類型
    @objc class func cnvApple2ABC(_ charCode: UniChar) -> UniChar {
        var charCode = charCode
        // 在按鍵資訊被送往 OVMandarin 之前，先轉換為可以被 OVMandarin 正常處理的資訊。
        if self.isDynamicBaseKeyboardLayoutEnabled() {
            // 保證 Apple 大千佈局內的符號鍵正常工作
            if charCode == 45 && (Preferences.basisKeyboardLayout == "com.apple.keylayout.ZhuyinBopomofo") { charCode = UniChar(96) }
            if charCode == 183 && (Preferences.basisKeyboardLayout == "com.apple.keylayout.ZhuyinEten") { charCode = UniChar(96) }
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
        }
        return charCode
    }

    @objc class func cnvStringApple2ABC(_ strProcessed: String) -> String {
        var strProcessed = strProcessed
        if self.isDynamicBaseKeyboardLayoutEnabled() {
            // 保證 Apple 大千佈局內的符號鍵正常工作
            if (strProcessed == "-" && Preferences.basisKeyboardLayout == "com.apple.keylayout.ZhuyinBopomofo") { strProcessed = "`" }
            if (strProcessed == "·" && Preferences.basisKeyboardLayout == "com.apple.keylayout.ZhuyinEten") { strProcessed = "`" }
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
        }
        return strProcessed
    }
}
