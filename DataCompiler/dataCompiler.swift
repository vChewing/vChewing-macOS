#!/usr/bin/env swift

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

import Foundation

// MARK: - 前導工作
extension String {
	fileprivate mutating func regReplace(pattern: String, replaceWith: String = "") {
		// Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
		do {
			let regex = try NSRegularExpression(
				pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
			let range = NSRange(self.startIndex..., in: self)
			self = regex.stringByReplacingMatches(
				in: self, options: [], range: range, withTemplate: replaceWith)
		} catch { return }
	}
}

// MARK: - 引入小數點位數控制函數
// Ref: https://stackoverflow.com/a/32581409/4162914
extension Float {
	fileprivate func rounded(toPlaces places: Int) -> Float {
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

infix operator **: ExponentiationPrecedence

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

private let urlCurrentFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private let urlCHSforCustom: String = "./components/chs/phrases-custom-chs.txt"
private let urlCHSforMCBP: String = "./components/chs/phrases-mcbp-chs.txt"
private let urlCHSforMOE: String = "./components/chs/phrases-moe-chs.txt"
private let urlCHSforVCHEW: String = "./components/chs/phrases-vchewing-chs.txt"

private let urlCHTforCustom: String = "./components/cht/phrases-custom-cht.txt"
private let urlCHTforMCBP: String = "./components/cht/phrases-mcbp-cht.txt"
private let urlCHTforMOE: String = "./components/cht/phrases-moe-cht.txt"
private let urlCHTforVCHEW: String = "./components/cht/phrases-vchewing-cht.txt"

private let urlKanjiCore: String = "./components/common/char-kanji-core.txt"
private let urlPunctuation: String = "./components/common/data-punctuations.txt"
private let urlMiscBPMF: String = "./components/common/char-misc-bpmf.txt"
private let urlMiscNonKanji: String = "./components/common/char-misc-nonkanji.txt"

private let urlOutputCHS: String = "./data-chs.txt"
private let urlOutputCHT: String = "./data-cht.txt"

// MARK: - 載入詞組檔案且輸出數組

func rawDictForPhrases(isCHS: Bool) -> [Entry] {
	var arrEntryRAW: [Entry] = []
	var strRAW: String = ""
	let urlCustom: String = isCHS ? urlCHSforCustom : urlCHTforCustom
	let urlMCBP: String = isCHS ? urlCHSforMCBP : urlCHTforMCBP
	let urlMOE: String = isCHS ? urlCHSforMOE : urlCHTforMOE
	let urlVCHEW: String = isCHS ? urlCHSforVCHEW : urlCHTforVCHEW
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
	} catch {
		NSLog(" - Exception happened when reading raw phrases data.")
		return []
	}
	// 預處理格式
	strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "")  // 去掉 macOS 標記
	// CJKWhiteSpace (\x{3000}) to ASCII Space
	// NonBreakWhiteSpace (\x{A0}) to ASCII Space
	// Tab to ASCII Space
	// 統整連續空格為一個 ASCII 空格
	strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
	strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "")  // 去除行尾行首空格
	strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")  // CR & Form Feed to LF, 且去除重複行
	strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "")  // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
	// 正式整理格式，現在就開始去重複：
	let arrData = Array(
		NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
	for lineData in arrData {
		// 第三欄開始是注音
		let arrLineData = lineData.components(separatedBy: " ")
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
		let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
		count = 0  // 不需要再定義，因為之前已經有定義過了。
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
		if phrase != "" {  // 廢掉空數據；之後無須再這樣處理。
			arrEntryRAW += [
				Entry.init(
					valPhone: phone, valPhrase: phrase, valWeight: 0.0,
					valCount: occurrence)
			]
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
	} catch {
		NSLog(" - Exception happened when reading raw core kanji data.")
		return []
	}
	// 預處理格式
	strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "")  // 去掉 macOS 標記
	// CJKWhiteSpace (\x{3000}) to ASCII Space
	// NonBreakWhiteSpace (\x{A0}) to ASCII Space
	// Tab to ASCII Space
	// 統整連續空格為一個 ASCII 空格
	strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
	strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "")  // 去除行尾行首空格
	strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")  // CR & Form Feed to LF, 且去除重複行
	strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "")  // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
	// 正式整理格式，現在就開始去重複：
	let arrData = Array(
		NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
	var varLineData: String = ""
	for lineData in arrData {
		// 簡體中文的話，提取 1,2,4；繁體中文的話，提取 1,3,4。
		let varLineDataPre = lineData.components(separatedBy: " ").prefix(isCHS ? 2 : 1)
			.joined(
				separator: "\t")
		let varLineDataPost = lineData.components(separatedBy: " ").suffix(isCHS ? 1 : 2)
			.joined(
				separator: "\t")
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
		let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
		count = 0  // 不需要再定義，因為之前已經有定義過了。
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
		if phrase != "" {  // 廢掉空數據；之後無須再這樣處理。
			arrEntryRAW += [
				Entry.init(
					valPhone: phone, valPhrase: phrase, valWeight: 0.0,
					valCount: occurrence)
			]
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
	} catch {
		NSLog(" - Exception happened when reading raw core kanji data.")
		return []
	}
	// 預處理格式
	strRAW = strRAW.replacingOccurrences(of: " #MACOS", with: "")  // 去掉 macOS 標記
	// CJKWhiteSpace (\x{3000}) to ASCII Space
	// NonBreakWhiteSpace (\x{A0}) to ASCII Space
	// Tab to ASCII Space
	// 統整連續空格為一個 ASCII 空格
	strRAW.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
	strRAW.regReplace(pattern: #"(^ | $)"#, replaceWith: "")  // 去除行尾行首空格
	strRAW.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n")  // CR & Form Feed to LF, 且去除重複行
	strRAW.regReplace(pattern: #"^(#.*|.*#WIN32.*)$"#, replaceWith: "")  // 以#開頭的行都淨空+去掉所有 WIN32 特有的行
	// 正式整理格式，現在就開始去重複：
	let arrData = Array(
		NSOrderedSet(array: strRAW.components(separatedBy: "\n")).array as! [String])
	var varLineData: String = ""
	for lineData in arrData {
		varLineData = lineData
		// 先完成某兩步需要分行處理才能完成的格式整理。
		varLineData = varLineData.components(separatedBy: " ").prefix(3).joined(
			separator: "\t")  // 提取前三欄的內容。
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
		let arrCells: [String] = varLineDataProcessed.components(separatedBy: "\t")
		count = 0  // 不需要再定義，因為之前已經有定義過了。
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
		if phrase != "" {  // 廢掉空數據；之後無須再這樣處理。
			arrEntryRAW += [
				Entry.init(
					valPhone: phone, valPhrase: phrase, valWeight: 0.0,
					valCount: occurrence)
			]
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
			norm += fscale ** (Float(entry.valPhrase.count) / 3.0 - 1.0)
				* Float(entry.valCount)
		}
	}
	// norm 計算完畢，開始將 norm 作為新的固定常數來為每個詞條記錄計算權重。
	// 將新酷音的詞語出現次數數據轉換成小麥引擎可讀的數據形式。
	// 對出現次數小於 1 的詞條，將 0 當成 0.5 來處理、以防止除零。
	for entry in arrStructUncalculated {
		var weight: Float = 0
		switch entry.valCount {
			case -2:  // 拗音假名
				weight = -13
			case -1:  // 單個假名
				weight = -13
			case 0:  // 墊底低頻漢字與詞語
				weight = log10(
					fscale ** (Float(entry.valPhrase.count) / 3.0 - 1.0) * 0.5 / norm)
			default:
				weight = log10(
					fscale ** (Float(entry.valPhrase.count) / 3.0 - 1.0)
						* Float(entry.valCount) / norm)  // Credit: MJHsieh.
		}
		let weightRounded: Float = weight.rounded(toPlaces: 3)  // 為了節省生成的檔案體積，僅保留小數點後三位。
		arrStructCalculated += [
			Entry.init(
				valPhone: entry.valPhone, valPhrase: entry.valPhrase, valWeight: weightRounded,
				valCount: entry.valCount)
		]
	}
	NSLog(" - \(i18n): 成功計算權重。")
	// ==========================================
	// 接下來是排序，先按照注音遞減排序一遍、再按照權重遞減排序一遍。
	let arrStructSorted: [Entry] = arrStructCalculated.sorted(by: { (lhs, rhs) -> Bool in
		return (lhs.valPhone, rhs.valCount) < (rhs.valPhone, lhs.valCount)
	})
	NSLog(" - \(i18n): 排序整理完畢，準備編譯要寫入的檔案內容。")
	return arrStructSorted
}

func fileOutput(isCHS: Bool) {
	let i18n: String = isCHS ? "簡體中文" : "繁體中文"
	let pathOutput = urlCurrentFolder.appendingPathComponent(
		isCHS ? urlOutputCHS : urlOutputCHT)
	var strPrintLine = ""
	// 讀取標點內容
	do {
		strPrintLine += try String(contentsOfFile: urlPunctuation, encoding: .utf8)
	} catch {
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
		strPrintLine +=
			entry.valPhone + " " + entry.valPhrase + " " + String(entry.valWeight)
			+ "\n"
	}
	NSLog(" - \(i18n): 要寫入檔案的內容編譯完畢。")
	do {
		try strPrintLine.write(to: pathOutput, atomically: false, encoding: .utf8)
	} catch {
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
