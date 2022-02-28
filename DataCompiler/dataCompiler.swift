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

import Foundation

// MARK: - 前導工作
fileprivate extension String {
    mutating func regReplace(pattern: String, replaceWith: String = "") {
        // Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: self.utf16.count)
            self = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch { return }
    }
}

fileprivate func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

// MARK: - 引入小數點位數控制函數
// Ref: https://stackoverflow.com/a/32581409/4162914
fileprivate extension Float {
    func rounded(toPlaces places:Int) -> Float {
        let divisor = pow(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}

// MARK: - 引入幂乘函數
// Ref: https://stackoverflow.com/a/41581695/4162914
precedencegroup ExponentiationPrecedence {
    associativity: right
    higherThan: MultiplicationPrecedence
}

infix operator ** : ExponentiationPrecedence

func ** (_ base: Double, _ exp: Double) -> Double {
    return pow(base, exp)
}

func ** (_ base: Float, _ exp: Float) -> Float {
    return pow(base, exp)
}

// MARK: - 定義檔案結構

struct Entry {
    var valPhone: String = ""
    var valPhrase: String = ""
    var valWeight: Float = -1.0
    var valCount: Int = 0
}

// MARK: - 登記全局根常數變數

fileprivate let urlCurrentFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

fileprivate let url_CHS_Custom: String = "./components/chs/phrases-custom-chs.txt"
fileprivate let url_CHS_MCBP: String = "./components/chs/phrases-mcbp-chs.txt"
fileprivate let url_CHS_MOE: String = "./components/chs/phrases-moe-chs.txt"
fileprivate let url_CHS_VCHEW: String = "./components/chs/phrases-vchewing-chs.txt"

fileprivate let url_CHT_Custom: String = "./components/cht/phrases-custom-cht.txt"
fileprivate let url_CHT_MCBP: String = "./components/cht/phrases-mcbp-cht.txt"
fileprivate let url_CHT_MOE: String = "./components/cht/phrases-moe-cht.txt"
fileprivate let url_CHT_VCHEW: String = "./components/cht/phrases-vchewing-cht.txt"

fileprivate let urlKanjiCore: String = "./components/common/char-kanji-core.txt"
fileprivate let urlPunctuation: String = "./components/common/data-punctuations.txt"
fileprivate let urlMiscBPMF: String = "./components/common/char-misc-bpmf.txt"
fileprivate let urlMiscNonKanji: String = "./components/common/char-misc-nonkanji.txt"

fileprivate let urlOutputCHS: String = "./data-chs.txt"
fileprivate let urlOutputCHT: String = "./data-cht.txt"

// MARK: - 載入詞組檔案且輸出數組

func rawDictForPhrases(isCHS: Bool) -> [Entry] {
    var arrEntryRAW: [Entry] = []
    var strRAW: String = ""
    let urlCustom: String = isCHS ? url_CHS_Custom : url_CHT_Custom
    let urlMCBP: String = isCHS ? url_CHS_MCBP : url_CHT_MCBP
    let urlMOE: String = isCHS ? url_CHS_MOE : url_CHT_MOE
    let urlVCHEW: String = isCHS ? url_CHS_VCHEW : url_CHT_VCHEW
    let i18n: String = isCHS ? "簡體中文" : "繁體中文"
    // 讀取內容
    do {
        strRAW += try String(contentsOfFile: urlCustom, encoding: .utf8)
        strRAW += "\n"
        strRAW += try String(contentsOfFile: urlMCBP, encoding: .utf8)
        strRAW += "\n"
        strRAW += try String(contentsOfFile: urlMOE, encoding: .utf8)
        strRAW += "\n"
        strRAW += try String(contentsOfFile: urlVCHEW, encoding: .utf8)
    }
    catch {
        NSLog(" - Exception happened when reading raw phrases data.")
        return []
    }
    // 預處理格式
    strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
    strRAW = strRAW.replacingOccurrences(of: "　", with: " ") // CJKWhiteSpace (\x{3000}) to ASCII Space
    strRAW = strRAW.replacingOccurrences(of: " ", with: " ") // NonBreakWhiteSpace (\x{A0}) to ASCII Space
    strRAW = strRAW.replacingOccurrences(of: "\t", with: " ") // Tab to ASCII Space
    strRAW.regReplace(pattern: "\\f", replaceWith: "\n") // Form Feed to LF
    strRAW = strRAW.replacingOccurrences(of: "\r", with: "\n") // CR to LF
    strRAW.regReplace(pattern: " +", replaceWith: " ") // 統整連續空格為一個 ASCII 空格
    // strRAW.regReplace(pattern: "\\n+", replaceWith: "\n") // 統整連續 LF 為一個 LF
    // (不需要處理純空行，因為空記錄不會被轉為 Entry)
    strRAW = strRAW.replacingOccurrences(of: " \n", with: "\n") // 去除行尾空格
    strRAW = strRAW.replacingOccurrences(of: "\n ", with: "\n") // 去除行首空格
    if strRAW.prefix(1) == " " { // 去除檔案開頭空格
        strRAW.removeFirst()
    }
    if strRAW.suffix(1) == " " { // 去除檔案結尾空格
        strRAW.removeLast()
    }
    // 正式整理格式，現在就開始去重複：
    let arrData = Array(NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
    var varLineData: String = ""
    for lineData in arrData {
        varLineData = lineData
        // 先完成某兩步需要分行處理才能完成的格式整理。
        varLineData.regReplace(pattern: "^#.*$", replaceWith: "") // 以#開頭的行都淨空
        varLineData.regReplace(pattern: "^.*#WIN32.*$", replaceWith: "") // 去掉所有 WIN32 特有的行
        // 第三欄開始是注音
        let arrLineData = varLineData.components(separatedBy: " ")
        var varLineDataProcessed: String = ""
        var count = 0
        for currentCell in arrLineData {
            count += 1
            if count < 3 {
                varLineDataProcessed += currentCell + "\t"
            } else if count < arrLineData.count {
                    varLineDataProcessed += currentCell + "-"
            } else {
                varLineDataProcessed += currentCell
            }
        }
        // 然後直接乾脆就轉成 Entry 吧。
        let arrCells : [String] = varLineDataProcessed.components(separatedBy: "\t")
        count = 0 // 不需要再定義，因為之前已經有定義過了。
        var phone = ""
        var phrase = ""
        var occurrence = 0
        for cell in arrCells {
            count += 1
            switch count {
            case 1: phrase = cell
            case 3: phone = cell
            case 2: occurrence = Int(cell) ?? 0
            default: break
            }
        }
        if phrase != "" { // 廢掉空數據；之後無須再這樣處理。
            arrEntryRAW += [Entry.init(valPhone: phone, valPhrase: phrase, valWeight: 0.0, valCount: occurrence)]
        }
    }
    NSLog(" - \(i18n): 成功生成詞語語料辭典（權重待計算）。")
    return arrEntryRAW
}

// MARK: - 載入單字檔案且輸出數組

func rawDictForKanjis(isCHS: Bool) -> [Entry] {
    var arrEntryRAW: [Entry] = []
    var strRAW: String = ""
    let i18n: String = isCHS ? "簡體中文" : "繁體中文"
    // 讀取內容
    do {
        strRAW += try String(contentsOfFile: urlKanjiCore, encoding: .utf8)
    }
    catch {
        NSLog(" - Exception happened when reading raw core kanji data.")
        return []
    }
    // 預處理格式
    strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
    strRAW = strRAW.replacingOccurrences(of: "　", with: " ") // CJKWhiteSpace (\x{3000}) to ASCII Space
    strRAW = strRAW.replacingOccurrences(of: " ", with: " ") // NonBreakWhiteSpace (\x{A0}) to ASCII Space
    strRAW = strRAW.replacingOccurrences(of: "\t", with: " ") // Tab to ASCII Space
    strRAW.regReplace(pattern: "\\f", replaceWith: "\n") // Form Feed to LF
    strRAW = strRAW.replacingOccurrences(of: "\r", with: "\n") // CR to LF
    strRAW.regReplace(pattern: " +", replaceWith: " ") // 統整連續空格為一個 ASCII 空格
    // strRAW.regReplace(pattern: "\\n+", replaceWith: "\n") // 統整連續 LF 為一個 LF
    // (不需要處理純空行，因為空記錄不會被轉為 Entry)
    strRAW = strRAW.replacingOccurrences(of: " \n", with: "\n") // 去除行尾空格
    strRAW = strRAW.replacingOccurrences(of: "\n ", with: "\n") // 去除行首空格
    if strRAW.prefix(1) == " " { // 去除檔案開頭空格
        strRAW.removeFirst()
    }
    if strRAW.suffix(1) == " " { // 去除檔案結尾空格
        strRAW.removeLast()
    }
    // 正式整理格式，現在就開始去重複：
    let arrData = Array(NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
    var varLineData: String = ""
    for lineData in arrData {
        varLineData = lineData
        // 先完成某兩步需要分行處理才能完成的格式整理。
        varLineData.regReplace(pattern: "^#.*$", replaceWith: "") // 以#開頭的行都淨空
        varLineData.regReplace(pattern: "^.*#WIN32.*$", replaceWith: "") // 去掉所有 WIN32 特有的行
        // 簡體中文的話，提取 1,2,4；繁體中文的話，提取 1,3,4。
        let varLineDataPre = varLineData.components(separatedBy: " ").prefix(isCHS ? 2 : 1).joined(separator: "\t")
        let varLineDataPost = varLineData.components(separatedBy: " ").suffix(isCHS ? 1 : 2).joined(separator: "\t")
        varLineData = varLineDataPre + "\t" + varLineDataPost
        let arrLineData = varLineData.components(separatedBy: " ")
        var varLineDataProcessed: String = ""
        var count = 0
        for currentCell in arrLineData {
            count += 1
            if count < 3 {
                varLineDataProcessed += currentCell + "\t"
            } else if count < arrLineData.count {
                    varLineDataProcessed += currentCell + "-"
            } else {
                varLineDataProcessed += currentCell
            }
        }
        // 然後直接乾脆就轉成 Entry 吧。
        let arrCells : [String] = varLineDataProcessed.components(separatedBy: "\t")
        count = 0 // 不需要再定義，因為之前已經有定義過了。
        var phone = ""
        var phrase = ""
        var occurrence = 0
        for cell in arrCells {
            count += 1
            switch count {
            case 1: phrase = cell
            case 3: phone = cell
            case 2: occurrence = Int(cell) ?? 0
            default: break
            }
        }
        if phrase != "" { // 廢掉空數據；之後無須再這樣處理。
            arrEntryRAW += [Entry.init(valPhone: phone, valPhrase: phrase, valWeight: 0.0, valCount: occurrence)]
        }
    }
    NSLog(" - \(i18n): 成功生成單字語料辭典（權重待計算）。")
    return arrEntryRAW
}

// MARK: - 載入非漢字檔案且輸出數組

func rawDictForNonKanjis(isCHS: Bool) -> [Entry] {
    var arrEntryRAW: [Entry] = []
    var strRAW: String = ""
    let i18n: String = isCHS ? "簡體中文" : "繁體中文"
    // 讀取內容
    do {
        strRAW += try String(contentsOfFile: urlMiscBPMF, encoding: .utf8)
        strRAW += "\n"
        strRAW += try String(contentsOfFile: urlMiscNonKanji, encoding: .utf8)
    }
    catch {
        NSLog(" - Exception happened when reading raw core kanji data.")
        return []
    }
    // 預處理格式
    strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
    strRAW = strRAW.replacingOccurrences(of: "　", with: " ") // CJKWhiteSpace (\x{3000}) to ASCII Space
    strRAW = strRAW.replacingOccurrences(of: " ", with: " ") // NonBreakWhiteSpace (\x{A0}) to ASCII Space
    strRAW = strRAW.replacingOccurrences(of: "\t", with: " ") // Tab to ASCII Space
    strRAW.regReplace(pattern: "\\f", replaceWith: "\n") // Form Feed to LF
    strRAW = strRAW.replacingOccurrences(of: "\r", with: "\n") // CR to LF
    strRAW.regReplace(pattern: " +", replaceWith: " ") // 統整連續空格為一個 ASCII 空格
    // strRAW.regReplace(pattern: "\\n+", replaceWith: "\n") // 統整連續 LF 為一個 LF
    // (不需要處理純空行，因為空記錄不會被轉為 Entry)
    strRAW = strRAW.replacingOccurrences(of: " \n", with: "\n") // 去除行尾空格
    strRAW = strRAW.replacingOccurrences(of: "\n ", with: "\n") // 去除行首空格
    if strRAW.prefix(1) == " " { // 去除檔案開頭空格
        strRAW.removeFirst()
    }
    if strRAW.suffix(1) == " " { // 去除檔案結尾空格
        strRAW.removeLast()
    }
    // 正式整理格式，現在就開始去重複：
    let arrData = Array(NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
    var varLineData: String = ""
    for lineData in arrData {
        varLineData = lineData
        // 先完成某兩步需要分行處理才能完成的格式整理。
        varLineData.regReplace(pattern: "^#.*$", replaceWith: "") // 以#開頭的行都淨空
        varLineData.regReplace(pattern: "^.*#WIN32.*$", replaceWith: "") // 去掉所有 WIN32 特有的行
        varLineData = varLineData.components(separatedBy: " ").prefix(3).joined(separator: "\t") // 提取前三欄的內容。
        let arrLineData = varLineData.components(separatedBy: " ")
        var varLineDataProcessed: String = ""
        var count = 0
        for currentCell in arrLineData {
            count += 1
            if count < 3 {
                varLineDataProcessed += currentCell + "\t"
            } else if count < arrLineData.count {
                    varLineDataProcessed += currentCell + "-"
            } else {
                varLineDataProcessed += currentCell
            }
        }
        // 然後直接乾脆就轉成 Entry 吧。
        let arrCells : [String] = varLineDataProcessed.components(separatedBy: "\t")
        count = 0 // 不需要再定義，因為之前已經有定義過了。
        var phone = ""
        var phrase = ""
        var occurrence = 0
        for cell in arrCells {
            count += 1
            switch count {
            case 1: phrase = cell
            case 3: phone = cell
            case 2: occurrence = Int(cell) ?? 0
            default: break
            }
        }
        if phrase != "" { // 廢掉空數據；之後無須再這樣處理。
            arrEntryRAW += [Entry.init(valPhone: phone, valPhrase: phrase, valWeight: 0.0, valCount: occurrence)]
        }
    }
    NSLog(" - \(i18n): 成功生成非漢字語料辭典（權重待計算）。")
    return arrEntryRAW
}

func weightAndSort(_ arrStructUncalculated: [Entry], isCHS: Bool) -> [Entry] {
    let i18n: String = isCHS ? "簡體中文" : "繁體中文"
    var arrStructCalculated: [Entry] = []
    let fscale: Float = 2.7
    var norm: Float = 0.0
    for entry in arrStructUncalculated {
        if entry.valCount >= 0 {
            norm += fscale**(Float(entry.valPhrase.count) / 3.0 - 1.0) * Float(entry.valCount) // Credit: MJHsieh.
        }
    }
    // norm 計算完畢，開始將 norm 作為新的固定常數來為每個詞條記錄計算權重。
    // 將新酷音的詞語出現次數數據轉換成小麥引擎可讀的數據形式。
    // 對出現次數小於 1 的詞條，將 0 當成 0.5 來處理、以防止除零。
    // 統計公式著作權歸 MJHsieh 所有（MIT License）。
    for entry in arrStructUncalculated {
        var weight: Float = 0
        switch entry.valCount {
        case -1: // 假名
            weight = -13
        case 0: // 墊底低頻漢字與詞語
            weight = log10(fscale**(Float(entry.valPhrase.count) / 3.0 - 1.0) * 0.5 / norm) // Credit: MJHsieh.
        default:
            weight = log10(fscale**(Float(entry.valPhrase.count) / 3.0 - 1.0) * Float(entry.valCount) / norm) // Credit: MJHsieh.
        }
        let weightRounded: Float = weight.rounded(toPlaces: 3) // 為了節省生成的檔案體積，僅保留小數點後三位。
        arrStructCalculated += [Entry.init(valPhone: entry.valPhone, valPhrase: entry.valPhrase, valWeight: weightRounded, valCount: entry.valCount)]
    }
    NSLog(" - \(i18n): 成功計算權重。")
    // ==========================================
    // 接下來是排序，先按照注音遞減排序一遍、再按照權重遞減排序一遍。
    let arrStructSorted: [Entry] = arrStructCalculated.sorted(by: {(lhs, rhs) -> Bool in return (lhs.valPhone, rhs.valCount) < (rhs.valPhone, lhs.valCount)})
    NSLog(" - \(i18n): 排序整理完畢，準備編譯要寫入的檔案內容。")
    return arrStructSorted
}

func fileOutput(isCHS: Bool) {
    let i18n: String = isCHS ? "簡體中文" : "繁體中文"
    let pathOutput = urlCurrentFolder.appendingPathComponent(isCHS ? urlOutputCHS : urlOutputCHT)
    var strPrintLine = ""
    // 讀取標點內容
    do {
        strPrintLine += try String(contentsOfFile: urlPunctuation, encoding: .utf8)
    }
    catch {
        NSLog(" - \(i18n): Exception happened when reading raw punctuation data.")
    }
    NSLog(" - \(i18n): 成功插入標點符號與西文字母數據。")
    // 統合辭典內容
    var arrStructUnified: [Entry] = []
    arrStructUnified += rawDictForKanjis(isCHS: isCHS)
    arrStructUnified += rawDictForNonKanjis(isCHS: isCHS)
    arrStructUnified += rawDictForPhrases(isCHS: isCHS)
    // 計算權重且排序
    arrStructUnified = weightAndSort(arrStructUnified, isCHS: isCHS)
    
    for entry in arrStructUnified {
        strPrintLine += entry.valPhone + " " + entry.valPhrase + " " + String(entry.valWeight) + "\n"
    }
    NSLog(" - \(i18n): 要寫入檔案的內容編譯完畢。")
    do {
        try strPrintLine.write(to: pathOutput, atomically: false, encoding: .utf8)
    }
    catch {
        NSLog(" - \(i18n): Error on writing strings to file: \(error)")
    }
    NSLog(" - \(i18n): 寫入完成。")
}

// MARK: - 主执行绪
func main() {
    NSLog("// 準備編譯繁體中文核心語料檔案。")
    fileOutput(isCHS: false)
    NSLog("// 準備編譯簡體中文核心語料檔案。")
    fileOutput(isCHS: true)
}

main()
